use Test::Base qw/no_plan/;
use FindBin;

{
    package TestApp;
    use Ark;
    use_plugins qw/MobileAgent/;


    package TestApp::Controller::Root;
    use Ark 'Controller';

    has '+namespace' => default => '';

    sub auto :Private {
        my ($self, $c) = @_;
        $c->res->content_type('text/html');
        1;
    }

    sub hello :Local {
        my ($self, $c) = @_;
        $c->res->body($c->req->param('q'));
    }
    
    sub redirect :Local {
        my ($self, $c) = @_;
        $c->redirect('/foo');
    }

    sub end :Private {
        my ($self, $c) = @_;
        $c->forward( $c->view('MobileJpFilter') );
    }


    package TestApp::View::MobileJpFilter;
    use Ark 'View::MobileJpFilter';
    __PACKAGE__->config->{filters} = [
        {
            module => 'Dummy',
            config => {
                prefix => 'dummy-test:{{',
                suffix => '}}',
            },
        },
    ];

}

use Ark::Test 'TestApp',
    components => [qw/Controller::Root View::MobileJpFilter/];

is get('/hello?q=foo'), 'dummy-test:{{foo}}', 'dummy filter';
unlike get('/redirect'), qr/dummy/, 'status 302';
