package Ark::View::MobileJpFilter;
use Ark 'View';

has html_filter => ( is => 'rw', isa => 'HTML::MobileJp::Filter', lazy => 1,
                     default => sub {
                         my $self = shift;
                         $self->ensure_class_loaded('HTML::MobileJp::Filter');
                         HTML::MobileJp::Filter->new( filters => $self->config->{filters} );
                     }
                 );
has visitor => ( is => 'rw', isa => 'Data::Visitor::Callback', lazy => 1,
                 default => sub {
                     my $self = shift;

                     $self->ensure_class_loaded('Data::Visitor::Callback');

                     my $v = Data::Visitor::Callback->new(
                         plain_value => sub {
                             return unless defined $_;
                             s{__path_to\((.*?)\)__}{ $self->path_to( $1 ? split( /,/, $1 ) : () ) }eg;
                         },
                     );
                     return $v;
                 }
             );

sub BUILD {
    my $self = shift;
    $self->visitor->visit;
};

sub render {
    my ($self, $c) = @_;
    
    $self->html_filter->filter(
        mobile_agent => $c->req->mobile_agent,
        html         => $c->res->body || "",
    );
}

sub process {
    my ($self, $c) = @_;
    
    return 1 if $c->req->method eq 'HEAD';
    return 1 if $c->res->status =~ /^(?:204|3\d\d)$/;
    return 1 unless $c->res->body;
    return 1 unless $c->res->content_type =~ /html$|xhtml\+xml$/;

    $c->res->body( $self->render($c) );

    return 1;
}

__PACKAGE__->meta->make_immutable;
