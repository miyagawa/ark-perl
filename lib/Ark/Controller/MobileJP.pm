package Ark::Controller::MobileJP;
use Ark 'Controller';
use Net::CIDR::MobileJP;

has 'cidr' => (
    is       => 'rw',
    isa      => 'Net::CIDR::MobileJP',
    lazy     => 1,
    default  => sub {
        Net::CIDR::MobileJP->new;
    },
);

has 'check_ua' => (
    is       => 'rw',
    isa      => 'Bool',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $conf = $self->class_config->{check_ua};
        defined $conf ? $conf : 1;
    },
);

has 'check_ip' => (
    is       => 'rw',
    isa      => 'Bool',
    lazy => 1,
    default => sub { 
        my $self = shift;
        my $conf = $self->class_config->{check_ip};
        defined $conf ? $conf : 1;
    },
);


sub authenticate_mobileid :Private {
    my ($self, $c) = @_;

    return unless $c->forward('confirm_mobile');
     
    $c->logout;

    my $authinfo = {};

    # mobile_id_field is default to 'mobile_id' in Ark::Plugin::Authentication::Credential::MobileID
    $authinfo->{mobile_id} = $c->req->mobile_agent->user_id; 

    my $user = $c->authenticate($authinfo);

    return $user;
}

sub confirm_mobile :Private {
    my ($self, $c) = @_;

    if ($self->check_ua && $c->req->mobile_agent->is_non_mobile) {
        $c->forward('_failed', 'user_agent is non_mobile');
        return 0;
    }
    
    if ($self->check_ip && ($self->cidr->get_carrier($c->req->address) eq 'N') ) {
        $c->forward('_failed', 'invalid mobile ip');
        return 0;
    }
    
    if (not eval { $c->req->mobile_agent->user_id }) {
        $c->forward('_failed','mobile_id required');
        return 0;
    }
    
    return 1;
}

sub _failed :Private {
    my ($self, $c, $reason) = @_;

    $self->log( debug => q|[Controller::Mobile] Failed to authenticate MobileID. Reason:'. %s |,
                $reason );
    warn "[Controller::Mobile]_failed: $reason\n";
}

1;
