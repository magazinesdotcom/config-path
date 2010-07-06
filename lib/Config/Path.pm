package Config::Path;
use Moose;

our $VERSION = '0.02';

use Config::Any;
use Hash::Merge;

=head1 NAME

Config::Path - Path-like config API with multiple file support and arbitrary backends from Config::Any

=head1 SYNOPSIS

    use Config::Path;

    my $conf = Config::Path->new(
        files => [ 't/conf/configA.yml', 't/conf/configB.yml' ]
    );

=head1 DESCRIPTION

Config::Path is a Yet Another Config module with a few twists that were desired
for an internal project:

=over 4

=item Multiple files merged into a single, flat hash

=item Path-based configuration value retrieval

=item Clean, simple implementation

=cut

=head2 Multiple-File Merging

If any of your config files contain the same keys, the "right" file wins, using
L<Hash::Merge>'s RIGHT_PRECEDENT setting.  In other words, later file's keys
will have precedence over those loaded earlier.

=head1 ATTRIBUTES

=cut

has '_config' => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
    clearer => 'reload'
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

The list of files that will be parsed for this configuration.

=cut

has 'files' => (
    traits => [ qw(Array) ],
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
    handles => {
        add_file => 'push'
    }
);

=head2 mask

A hashref of "masked" values that will be consulted before the I<real> config
is consulted.  This allows you to override individual configuration values.
Defaults to undefined.  You can override values using C<override>.

=cut

has 'mask' => (
    is => 'rw',
    isa => 'HashRef',
    predicate => 'has_mask',
    clearer => 'clear_override'
);

sub _build__config {
    my ($self) = @_;

    my $anyconf = Config::Any->load_files({ %{ $self->config_options }, files => $self->files });

    my $config = ();
    my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
    foreach my $file (keys(%{ $anyconf })) {
        $config = $merge->merge($config, $anyconf->{$file});
    }
    if(defined($config)) {
        return $config;
    }

    return {};
}

=head1 METHODS

=head2 add_file ($file)

Adds the supplied filename to the list of files that will be loaded.  Note
that adding a file after you've already loaded a config will not change
anything.  You'll need to call C<reload> if you want to reread the
configuration and include the new file.

=head2 clear_override

Clear all values covered by C<override>.

=head2 fetch ($path)

Get a value from the config file.  As per the name of this module, fetch takes
a path argument in the form of C</foo/bar/baz>.  This is effectively a
shorthand way of expressing a series of hash keys.  Whatever value is on
the end of the keys will be returned.  As such, fetch might return undef,
scalar, arrayref, hashref or whatever you've stored in the config file.

  my $foo = $config->fetch('/baz/bar/foo');

=cut

sub fetch {
    my ($self, $path) = @_;

    # Check the mask first to see if the path we've been given has been
    # overriden.
    if($self->has_mask) {
        # Use exists just in case they set the value to undef.
        return $self->mask->{$path} if exists($self->mask->{$path});
    }

    my $conf = $self->_config;
    foreach my $piece (split(/\//, $path)) {
        $conf = $conf->{$piece};
        return undef unless defined($conf);
    }

    return $conf;
}

=head2 override ('path/to/value', 'newvalue')

Override the specified key to the specified value. Note that this only changes
the path's value in this instance. It does not change the config file. This is
useful for tests.  Note that C<exists> is used so setting a path to undef
will not clear the override.  If you want to clear overrides use
C<clear_override>.

=cut

sub override {
    my ($self, $path, $value) = @_;

    # Set the mask if there isn't one.
    $self->mask({}) unless $self->has_mask;

    # No reason to create a hierarchical setup here, just use the path as
    # the key.
    $self->mask->{$path} = $value;
}

=head2 reload

Rereads the config files specified in C<files>.  Well, actually it just blows
away the internal state of the config so that the next call will reload the
configuration. Note that this also clears any C<override>ing you've done.

=cut

after 'reload' => sub {
    my $self = shift;
    $self->clear_override;
};

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
