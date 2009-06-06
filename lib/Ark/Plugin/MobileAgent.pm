package Ark::Plugin::MobileAgent;
use Ark::Plugin;
use HTTP::MobileAgent;

{
    package Ark::Request;

    sub mobile_agent {
        my $self = shift;
        unless ( $self->{ mobile_agent } ) {
            $self->{ mobile_agent } = HTTP::MobileAgent->new( $self->headers );
        }
        return $self->{ mobile_agent };
    }
}

{
    no warnings 'redefine';
    *HTTP::MobileAgent::Request::new = sub {
        my($class, $stuff) = @_;
        if (!defined $stuff) {
            bless { env => \%ENV }, 'HTTP::MobileAgent::Request::Env';
        }
        elsif (UNIVERSAL::isa($stuff, 'Apache')) {
            bless { r => $stuff }, 'HTTP::MobileAgent::Request::Apache';
        }
        elsif ( UNIVERSAL::isa($stuff, 'HTTP::Headers') || UNIVERSAL::isa($stuff, 'HTTP::Headers::Fast') ) {
            bless { r => $stuff }, 'HTTP::MobileAgent::Request::HTTPHeaders';
        }
        else {
            bless { env => { HTTP_USER_AGENT => $stuff } }, 'HTTP::MobileAgent::Request::Env';
        }
    };
}

1;
