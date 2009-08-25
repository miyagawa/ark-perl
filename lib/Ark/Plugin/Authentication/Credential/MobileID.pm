package Ark::Plugin::Authentication::Credential::MobileID;
use Ark::Plugin 'Auth';

has cred_mobile_mobileid_field => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->class_config->{mobile_id_field} || 'mobile_id';
    },
);

around authenticate => sub {
    my $prev = shift->(@_);
    return $prev if $prev;

    my ($self, $info) = @_;

    my $id = $info->{ $self->cred_mobile_mobileid_field };
    if (my $user = $self->find_user($id, $info)) {
        $self->persist_user($user);
        return $user;
    }

    return;
};



1;
