package Config::Path;
use Moose;

our $VERSION = '0.07';

use Config::Any;
use Hash::Merge;

=head1 NAME

Config::Path - Path-like config API with multiple file support, directory
loading and arbitrary backends from Config::Any.

=head1 SYNOPSIS

    use Config::Path;

    my $conf = Config::Path->new(
        files => [ 't/conf/configA.yml', 't/conf/configB.yml' ]
    );

    # Or, if you want to load all files in a directory

    my $dconf = Configh::Path->new(
        directory => 'myapp/conf'
    );

=head1 DESCRIPTION

Config::Path is a Yet Another Config module with a few twists that were desired
for an internal project:

=over 4

=item Multiple files merged into a single, flat hash

=item Path-based configuration value retrieval

=item Support for loading all config files in a directory

=item Sane precedence for key collisions

=item Clean, simple implementation

=cut

=head2 Multiple-File Merging

If any of your config files contain the same keys, the "right" file wins, using
L<Hash::Merge>'s RIGHT_PRECEDENT setting.  In other words, later file's keys
will have precedence over those loaded earlier.

Note that when a full directory of files are loaded the files are sorted via
Perl's C<sort> before merging so as to remove any amigiuity about the order
in which they will be loaded.

=head2 Directory Slurping

If you specify a value for the C<directory> attribute, rather than the C<files>
attribute then Config::Path will attempt to load all the files in the supplied
directory via Config::Any.  B<The files will be merged in alphabetical order
so that there is no ambiguity in the event of a key collision.  Files later
in the alphabet will override keys of their predecessors.

=head2 Arrays

Arrays can be accessed with paths like C<foo/0/bar>.  Just use the array index
to descend into that element.  If you attempt to treat a hash like an array
or an array like hash you will simply get C<undef> back.

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

=head2 directory

A directory in which files should be searched for.  Note that this option is
mutually-exclusive to the C<files> attribute.  Only set one of them.

=cut

has 'directory' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_directory'
);

=head2 files

The list of files that will be parsed for this configuration.  Note that this
option is mutually-exclusive to the C<files> attribute.  Only set one of them.

=cut

has 'files' => (
    traits => [ qw(Array) ],
    is => 'ro',
    isa => 'ArrayRef',
    predicate => 'has_files',
    handles => {
        add_file => 'push'
    }
);

has '_mask' => (
    is => 'rw',
    isa => 'HashRef',
    predicate => 'has_mask',
    clearer => 'clear_mask'
);

sub BUILD {
    my ($self) = @_;

    if($self->has_directory && $self->has_files) {
        die "directory and files are mutually exclusive, choose one"
    }

    unless($self->has_directory || $self->has_files) {
        die "One of directory or files must be specified"
    }
}

sub _build__config {
    my ($self) = @_;

    # This might be undef, but that's ok.  We'll check later.
    my $files = $self->files;

    # Check for a directory
    if($self->has_directory) {
        my $dir = $self->directory;

        unless(-d $dir) {
            die "Can't open directory: $dir";
        }

        opendir(my $dh, $dir);
        my @files = sort(map("$dir/$_", grep { $_ !~ /^\./ && -f  "$dir/$_" } readdir($dh)));
        closedir($dh);

        $files = \@files;
    }

    if(!defined($files) || scalar(@{ $files }) < 1) {
        warn "No files found.";
    }

    my $anyconf = Config::Any->load_files({ %{ $self->config_options }, files => $files });

    my $config = ();
    my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
    foreach my $file (@{ $files }) {
        # Double check that it exists, as Config::Any might not have loaded it
        next unless exists $anyconf->{$file};
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

=head2 clear_mask

Clear all values covered by C<mask>.

=head2 fetch ($path)

Get a value from the config file.  As per the name of this module, fetch takes
a path argument in the form of C<foo/bar/baz>.  This is effectively a
shorthand way of expressing a series of hash keys.  Whatever value is on
the end of the keys will be returned.  As such, fetch might return undef,
scalar, arrayref, hashref or whatever you've stored in the config file.

  my $foo = $config->fetch('baz/bar/foo');

Note that leading slashes will be automatically stripped, just in case you
prefer the idea of using them.  They are effectively useless though.

=cut

sub fetch {
    my ($self, $path) = @_;

    # Check the mask first to see if the path we've been given has been
    # overriden.
    if($self->has_mask) {
        # Use exists just in case they set the value to undef.
        return $self->_mask->{$path} if exists($self->_mask->{$path});
    }

    $path =~ s/^\///g; # Remove leading slashes, as they don't do anything
                       # and there's no reason to break over it.

    my $conf = $self->_config;
    foreach my $piece (split(/\//, $path)) {
        if(ref($conf) eq 'HASH') {
            $conf = $conf->{$piece};
        } elsif(ref($conf) eq 'ARRAY' && $piece =~ /\d+/) {
            $conf = $conf->[$piece];
        } else {
            # Not sure what they asked for, but it's not gonna work.  Maybe a
            # string member of an array?
            $conf = undef;
        }
        return undef unless defined($conf);
    }

    return $conf;
}

=head2 mask ('path/to/value', 'newvalue')

Override the specified key to the specified value. Note that this only changes
the path's value in this instance. It does not change the config file. This is
useful for tests.  Note that C<exists> is used so setting a path to undef
will not clear the mask.  If you want to clear masks use C<clear_mask>.

=cut

sub mask {
    my ($self, $path, $value) = @_;

    # Set the mask if there isn't one.
    $self->_mask({}) unless $self->has_mask;

    # No reason to create a hierarchical setup here, just use the path as
    # the key.
    $self->_mask->{$path} = $value;
}

=head2 reload

Rereads the config files specified in C<files>.  Well, actually it just blows
away the internal state of the config so that the next call will reload the
configuration. Note that this also clears any C<mask>ing you've done.

=cut

after 'reload' => sub {
    my $self = shift;
    $self->clear_mask;
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
