use Test::Base qw/no_plan/;

{
    package TestApp;
    use Ark;
    use_plugins qw/
        MobileAgent
    /;
    conf 'Controller::Mobile' => {
        check_ua => 1,
        check_ip => 1,
    };

    package TestApp::Controller::Root;
    use Ark 'Controller::MobileJP';

    has '+namespace' => default => '';
    has '+cidr'      => default => sub { Net::CIDR::MobileJP->new({ E => ['127.0.0.1/0'] }) };

    sub confirm :Local {
        my ($self, $c) = @_;
        $c->res->body( $c->forward('confirm_mobile') ? 'ok' : 'ng' );
    }
}

use Ark::Test 'TestApp',
    components => [qw/Controller::Root/];
use HTTP::Request::Common;

is( request( GET( '/confirm',
                  'User-Agent' => 'DoCoMo/2.0 N2001(c10;ser0123456789abcde;icc01234567890123456789)',
                  'x-dcmguid'  => '0000000',
              ) )->content
    , 'ok', 'ok');
is( request( GET( '/confirm', 'User-Agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; ja; rv:1.9.1.2) Gecko/20090729 Firefox/3.5.2 (.NET CLR 3.5.30729)', ) )->content
    , 'ng', 'ng(ua)-ok');
is( request( GET( '/confirm',
                  'User-Agent' => 'DoCoMo/2.0 N2001(c10;ser0123456789abcde;icc01234567890123456789)',
              ) )->content
    , 'ng', 'ng(mobile_id)-ok');
