package Ark::Plugin::Session::State::URI;

use Ark::Plugin 'Session';

use HTML::TokeParser::Simple;
use MIME::Types;
use URI;
use URI::Find;
use URI::QueryParam;

has 'rewrite' => (
    is       => 'rw',
    isa      => 'Bool',
    lazy    => 1,
    default  => sub {
        my $self = shift;
        $self->class_config->{rewrite}
            || $self->app->config->{session}{rewrite}
            || 1 ;
    },
);

has 'rewrite_types' => (
    is       => 'rw',
    isa      => 'Maybe[ArrayRef[Str]]',
    lazy    => 1,
    default  => sub { 
        my $self = shift;
        $self->class_config->{rewrite_types}
            || $self->app->config->{session}->{rewrite_types}
            || undef ;
    },
);

has 'no_rewrite_if_cookie' => (
    is       => 'rw',
    isa      => 'Bool',
    lazy    => 1,
    default  => sub {
        my $self = shift;
        $self->class_config->{no_rewrite_if_cookie}
            || $self->app->config->{session}{no_rewrite_if_cookie}
            || 1 ;
    },
);

has 'param' => (
    is       => 'rw',
    isa      => 'Str',
    lazy    => 1,
    default  => sub { 
        my $self = shift;
        $self->class_config->{param}
            || $self->app->config->{'session'}{param}
            || 'sid' ;
    }
);

has '_sessionid_from_uri' => (
    is       => 'rw',
    isa      => 'Str',
);

has '_sessionid_to_rewrite' => (
    is       => 'rw',
    isa      => 'Str',
);

has '_session_rewriting_html_tag_map' => (
    is       => 'ro',
    isa      => 'HashRef',
    default  => sub { +{
        a      => "href",
        form   => "action",
        link   => "href",
        img    => "src",
        script => "src",
    } },
);


has '_session_other_state_plugin_enabled' => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 0,
);

has 'overload_uri_for' => (
    is       => 'rw',
    isa      => 'Bool',
    lazy    => 1,
    default  => sub { 
        my $self = shift;
        $self->class_config->{param}
            || $self->app->config->{'session'}{param}
            || 1;
    },
);

sub BUILD {
    my ($self) = @_;
    
    my $ctx  = $self->app->context_class;
    my $role = 'Ark::Plugin::Session::State::URI::ExtendContext';

    return if $ctx->meta->does_role($role);

    $self->ensure_class_loaded($role);
    $role->meta->apply( $ctx->meta );
}

sub get_session_id_from_param {
    my ($self) = @_;
    my $request = $self->context->request;
    
    my $param = $self->param;
    
    if ( my $sid = $request->param($param) ) {
        $self->log( debug => q[Found sessionid "%s" in query parameters], $sid );

        $self->_sessionid_from_uri($sid);

        return $sid;
    }

    return;
}

around 'get_session_id' => sub {
    my $next = shift;
    my ($self)  = @_;
    if ( my $ret = $next->(@_) ){
        $self->log( debug => q[***get_session_id next returns: %s], $ret );
        $self->_session_other_state_plugin_enabled(1);
        return $ret;
    }

    $self->log( debug => q[***get_session_id] );
    if ( my $param = $self->get_session_id_from_param() ) {
        $self->_sessionid_from_uri($param);
        return $self->_sessionid_from_uri;
    }
};

around 'set_session_id' => sub {
    my $next = shift;
    my ($self, $sid) = @_;

    # Ark::Plugin::Session::State::Cookie
    $self->_sessionid_to_rewrite($sid);
    $self->log( debug => q[***set_session_id set sessionid: %s], $sid );

    $next->(@_)
};

around 'remove_session_id' => sub {
    my $next = shift;
    my ($self, $sid) = @_;

    $self->session_id(undef);
    $self->_sessionid_from_uri(undef);
    $self->_sessionid_to_rewrite(undef);

    $next->(@_);
};

around 'finalize_session' => sub {
    my $next   = shift;
    my ($self, $res) = @_;

    $self->session_rewrite_if_needed;

    $next->(@_);
};

sub session_rewrite_if_needed {
    my $self = shift;

    my $sid = $self->_sessionid_to_rewrite || $self->_sessionid_from_uri;

    if ( $sid and $self->session_should_rewrite ) {
        $self->log( debug => q[rewriting response elements to include session id] );


        if ( $self->session_should_rewrite_redirect ) {
            $self->rewrite_redirect_with_session_id($sid);
        }

        if ( $self->session_should_rewrite_body ) {
            $self->rewrite_body_with_session_id($sid);
        }
    }
}

# TODO dont rewrite if Session::State::Cookie is enabled
sub session_should_rewrite {
    my $self = shift;

    return unless $self->rewrite;

    if ($self->no_rewrite_if_cookie
            and
        $self->_session_other_state_plugin_enabled
    ) {
        $self->log( debug => q[*** session shoudn' rewrite _session_other_state_plugin_enabled is %s],
                    $self->_session_other_state_plugin_enabled );
        return 0;
    }
    
    return 1;
}

sub session_should_rewrite_redirect {
    my $self = shift;
    my $res = $self->context->response;


    ($res->status || 0) =~ /^\s*3\d\d\s*$/;
}

sub rewrite_redirect_with_session_id {
    my ($self, $sid) = @_;
    my $res = $self->context->response;

    my $location = $res->header('Location') || return;
    
    if ( $self->session_should_rewrite_uri($location) ) {
        my $uri_with_sid = $self->uri_with_sessionid($location, $sid);
        $self->log( debug => q[Rewriting location header %s to %s ], 
                    $location, $uri_with_sid );
    }
}


# is $self->context->request->base URI object？ am i right？
# Note, currently suport param style rewriting only.
sub session_should_rewrite_uri {
    my ($self, $uri_str) = @_;
    
    my $req = $self->context->request;
    my $uri = eval { URI->new($uri_str) } || return;

    # ignore the url outside    
    my $rel = $uri->abs($req->base);
    
    return unless index ($rel, $req->base) == 0;
    return unless $self->session_should_rewrite_uri_mime_type($rel);

    # currently suport param style rewriting only
    if ( my $param = $self->{param} ) {
        # use param style rewriting
        # if the URI query string doesn't contain $param
        return not defined $uri->query_param($param);
    }
    
    # TODO XXX
    return;
}

sub session_should_rewrite_uri_mime_type {
    my ($self, $uri) = @_;

    # ignore media type such as gif, pdf and etc
    if ( $uri->path =~ m#\.(\w+)(?:\?|$)# ) {
        my $mt = new MIME::Types->mimeTypeOf($1);

        if ( ref $mt ) {
            return if $mt->isBinary;
        }
    }

    return 1;    
}

sub session_should_rewrite_body {
    my ($self) = @_;

    if ( my $types = $self->rewrite_types ) {
        my $res = $self->context->response;
        my @req_type = $res->content_type; # split

        foreach my $type ( @$types ) {
            # don't support subclass of type. difference C::P::Session::State::URI;
            return 1 if lc($type) eq $req_type[0];
        }

        return;
    }

    return 1;
}

sub rewrite_body_with_session_id {
    my ($self, $sid) = @_;
    my $res = $self->context->response;

    my $content_type_is_html = sub {
        ($res->content_type || '') =~ /html/
    };

    my $body_looks_like_html = sub {
        !$res->content_type 
            and
        $res->body =~ /^\s*\w*\s*<[?!]?\s*\w+/
    };

    if ( $content_type_is_html->() or $body_looks_like_html->() ) {
        $self->rewrite_html_with_session_id($sid);
    }
    else {
        $self->rewrite_text_with_session_id($sid);
    }
}

sub rewrite_html_with_session_id {
    my ($self, $sid) = @_;

    my $res = $self->context->response;

    return if not $res->body;

    $self->log( debug => q[Rewriting HTML body with the token parser] );

    my $tokeparser = HTML::TokeParser::Simple->new( string => ( $res->body ) );
    my $tag_map = $self->_session_rewriting_html_tag_map;
    
    my $body = '';
    while ( my $token = $tokeparser->get_token ) {
        if ( my $tag = $token->get_tag ) {
            # rewrite tags according to the map
            if ( my $attr_name = $tag_map->{$tag} ) {
                if ( defined(my $attr_value = $token->get_attr($attr_name) ) ) {
                    $attr_value = $self->uri_with_sessionid($attr_value, $sid)
                        if $self->session_should_rewrite_uri($attr_value);

                    $token->set_attr( $attr_name, $attr_value );
                }
            }
        }

        $body .= $token->as_is;
    }

    $res->body($body);
}

sub rewrite_text_with_session_id {
    my ($self, $sid) = @_;
    my $res = $self->context->response;
    my $res_body = $res->body;

    $self->log( debug => q[Rewriting plain body with URI::Find] );
    
    URI::Find->new(sub {
        my ( $uri, $orig_uri ) = @_;
        
        if ( $self->session_should_rewrite_uri($uri) ) {
            my $rewritten = $self->uri_with_sessionid($uri, $sid);
            if ( $orig_uri =~ s/\Q$uri/$rewritten/ ) {
                # try to keep formatting
                return $orig_uri;
            } elsif ( $orig_uri =~ /^(<(?:URI:)?).*(>)$/ ) {
                return "$1$rewritten$2";
            } else {
                return $rewritten;
            }
        } else {
            return $orig_uri;
        }
    })->find( \$res_body );

    $res->body($res_body);
}

# $c->sessionid  siraberu
sub uri_with_sessionid {
    my ($self, $uri, $sid) = @_;
    
    $sid  ||= $self->session_id;
    $self->log( debug => q[uri_with_sessionid Found sessionid "%s"], $sid||'' );
    
    my $uri_obj = eval { URI->new($uri) } || return $uri;
    
    # Currently path style rewriting is not supported.
    return $self->uri_with_param_sessionid($uri_obj, $sid);
}

sub uri_with_param_sessionid {
    my ($self, $uri_obj, $sid) = @_;

    my $param_name = $self->param;
    
    $uri_obj->query_param( $param_name => $sid );

    return $uri_obj;
}


1;
