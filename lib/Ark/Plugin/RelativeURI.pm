package Ark::Plugin::RelativeURI;
use Ark::Plugin; 

use URI::SmartURI;

=head1 precondition

Ark::Plugin::Session::State::URI
Ark::Plugin::MobileAgent

=cut


=item uri_for

Plugin::Session::State::URIと同時使用の場合,
先にState::URIのuri_forが処理された後にここを通る
その後View::MobileJPFilterのDoCoMoGUIDが動く

=cut

around uri_for => sub {
    my $next = shift;
    my ($c, @path) = @_;

    my $uri = $next->(@_);
    
    if ( $c->req->mobile_agent->is_docomo ) {
        my $res = URI::SmartURI->new($uri, {
            reference => $c->req->uri,
        })->relative;
        return $res;
    }

    return $uri;
};


1;
