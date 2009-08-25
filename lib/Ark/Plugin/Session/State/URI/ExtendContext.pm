package Ark::Plugin::Session::State::URI::ExtendContext;
use Ark::Plugin;

around uri_for => sub {
    my $next      = shift;
    my ($context) = @_;

    my $session = $context->session;
    
    if ( $session->_session_other_state_plugin_enabled ) {
        return $next->(@_);
    }

    return $session->overload_uri_for
         ? $session->uri_with_sessionid($next->(@_))
         : $next->(@_);
};

1;
