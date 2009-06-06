use Test::Base qw/no_plan/;

{
    package TestApp;
    use Ark;

    use_plugins qw/
        MobileAgent
        /;

    package TestApp::Controller::Root;
    use Ark 'Controller';
    use Test::More;

    has '+namespace' => default => '';

    sub foo :Global {
        my ( $self, $c ) = @_;
        my $mobile_agent = $c->req->mobile_agent;
        $c->res->body( $mobile_agent->user_agent );
    }
}

use Ark::Test 'TestApp',
    components       => [qw/Controller::Root/];
use HTTP::Request::Common;

my @Tests = (
    {
        class      => 'HTTP::MobileAgent::DoCoMo',
        user_agent => 'DoCoMo/2.0 N2001(c10;ser0123456789abcde;icc01234567890123456789)',
        carrier    => 'DoCoMo',
    },
    {
        class      => 'HTTP::MobileAgent::EZweb',
        user_agent => 'KDDI-TS21 UP.Browser/6.0.2.276 (GUI) MMP/1.1',
        carrier    => 'EZweb',
    },
    {
        class      => 'HTTP::MobileAgent::JPhone',
        user_agent => 'SoftBank/1.0/910T/TJ001 Browser/NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1',
        carrier    => '(Vodafone|SoftBank)',
    },
);

for my $Test ( @Tests ) {
    is( request( GET( 
        '/foo',
        'User-Agent' => $Test->{ user_agent },
    ) )->content, $Test->{ user_agent }, "User-Agent $Test->{class} ok" );
}
