use Test::Base qw(no_plan);

use FindBin;
use lib "$FindBin::Bin/../../lib";

{
    package TestApp;
    use Ark;

    use_plugins qw/
        Session
        Session::State::URI
        Session::Store::Memory
        /;

    conf 'Plugin::Session::State::URI' => {
        param => 'sid',
    };

    package TestApp::Controller::Root;
    use Ark 'Controller';

    has '+namespace' => default => '';

    sub test_set :Local {
        my ($self, $c) = @_;
        $c->session->set('test', 'dummy');

        my $sid = $c->session->session_id;

        $c->res->body( $sid );
    }

    sub test_get :Local {
        my ($self, $c) = @_;

        my $ses_val = $c->session->get('test');
        
        $c->res->body( $ses_val );
    }

    sub rewrite_test :Local {
        my ($self, $c) = @_;

        my $body = $c->req->param('body');

        $c->session->set('test' => 'dummy');

        $c->res->body( qq{$body} );
    }

    sub shoud_not_rewrite_test :Local {
        my ($self, $c) = @_;
        my $req = $c->req;
        my $body = $req->param('body');

        # external URL
        $req->uri( URI->new('http://other-host.com'). $req->uri->path  );
        $req->header( Host => 'localhost' );

        $c->session->set('test' => 'dummy');

        $c->res->body( my $body_ext_url = qq{$body} );
    }

    sub rewrite_location_header :Local {
        my ($self, $c) = @_;

        my $base = $c->req->param('base');
        my $body = $c->req->param('body');
        my $uri = $c->req->param('uri');
        $c->session->set('test' => 'dummy');

        $c->redirect( $c->uri_for($uri) );

        $c->res->body( qq{$uri} );
    }

    sub shoud_not_rewrite_location :Local {
        my ($self, $c) = @_;
        
        my $uri = $c->req->param('uri');
        $c->session->set('test');

        $c->redirect($uri);

        $c->res->body($uri);
    }
}

use Ark::Test 'TestApp',
    components       => [qw/Controller::Root/],
    reuse_connection => 1;

use Smart::Comments;
use HTTP::Request::Common;

# set, get
{
    my $res = request(GET '/test_set');
    my $sid = $res->content;
    ok($sid, 'session set ok');

    my $get_session_res = request(POST '/test_get', [sid => $sid] );
    is($get_session_res->content, 'dummy', 'session get ok');
    
}

# external URL shoud not rewrite
{
    my $external_uri = "http://www.woobling.org/";
    my $rel_with_slash_ext   = "/fajkhat";
    my $rel_with_dot_dot     = "../ljaht";
    for my $uri ($external_uri, $rel_with_slash_ext, $rel_with_dot_dot) {
        my $body = qq{foo <a href="$uri"></a> blah};
        my $res = request(POST '/shoud_not_rewrite_test', [body => $body] );
    
        is( $res->content, $body, "external URL stays untouched");
    }
}

# rewrite redirect
{
    my $relative_uri = "maria";
    my $rel_with_slash = "/bless/you";
    
    for my $uri ($relative_uri, $rel_with_slash) {
        my $body = qq{foo <a href="$uri"></a> blah};
        my $res = request(POST '/rewrite_location_header', [
            body => $body,
            uri  => $uri,
        ] );

        my $location = $res->header('Location');
        like($location, qr/$uri.+sid=[a-z0-9]+$/, 'location header was rewritten');
    }
}

# redirect to external shoud not be rewritten
{
    my $external_uri = "http://www.woobling.org/";
    for my $uri ($external_uri) {
        my $res = request(POST '/shoud_not_rewrite_location', [
            uri  => $uri,
        ] );
        my $location = $res->header('Location');
        
        is($location, $uri, 'external URL stays untouched');
    }
}


### rewrite

filters {
    input    => [qw/chomp/],
    expected => [qw/chomp/],
};

sub do_test {
    my ($input, $expected, $desc) = @_;
    
    my $res = request(POST '/rewrite_test', [body => $input]);
    my $re = qr/$expected/;
    like( $res->content, $re, $desc );
}

run {
    my $block = shift;
    my $input = $block->input;
    my $expected = $block->expected;
    my $desc = $block->name;

    do_test($input, $expected, $desc);
}

__END__
=== a tag
--- input
<a href="/test">blah</a>
--- expected
/test?.+sid=[a-z0-9]+
=== img tag
--- input
<img src="/static/header"/>
--- expected
/static/header?.+sid=[a-z0-9]+
=== link tag
--- input
<link rel="stylesheet" type="text/css" href="/static/site.css" />
--- expected
/static/site.css?.+sid=[a-z0-9]+
=== form tag
--- input
<form action="/foo" method="post"></form>
--- expected
/foo?.+sid=[a-z0-9]+
--- LAST

