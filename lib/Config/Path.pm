package Config::Path;
use Moose;

our $VERSION = '0.01';

use Config::Any;
use Hash::Merge;

=head1 NAME

Config::Path - Path-like config API with multiple file support and arbitrary backends from Config::Any

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Config::Path;

    my $foo = Config::Path->new();
    ...

=head1 ATTRIBUTES

=cut

has '_config' => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1
);

=head2 config_options

HashRef of options passed to Config::Any.

=cut

has 'config_options' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {
        flatten_to_hash => 1,
        use_ext => 1
    } }
);

=head2 files

=cut

has 'files' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] }
);

=head1 METHODS

=cut

sub _build__config {
    my ($self) = @_;

    my $opts = $self->config_options;
    $opts->{files} = $self->files;

    my $anyconf = Config::Any->load_files($opts);

    my $config = ();
    my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
    foreach my $file (keys(%{ $anyconf })) {
        $config = $merge->merge($config, $anyconf->{$file});
    }
    return $config;
}

=head2 fetch

=cut

sub fetch {
    my ($self, $path) = @_;

    my $conf = $self->_config;
    foreach my $piece (split(/\//, $path)) {
        $conf = $conf->{$piece};
        return undef unless defined($conf);
    }

    return $conf;
}

=head1 AUTHOR

Cory G Watson, C<< <gphat at cpan.org> >>

=head1 ACKNOWLEDGEMENTS

 Jay Shirley
 Mike Eldridge

=head1 COPYRIGHT & LICENSE

Copyright 2010 Magazines.com

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
