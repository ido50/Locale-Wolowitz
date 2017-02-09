package Locale::Wolowitz;

# ABSTRACT: Dead simple localization with JSON.

use warnings;
use strict;
use utf8;

use Carp;
use JSON::MaybeXS qw/JSON/;

our $VERSION = "1.004001";
$VERSION = eval $VERSION;

=encoding utf-8

=head1 NAME

Locale::Wolowitz - Dead simple localization with JSON.

=head1 SYNOPSIS

	# in ./i18n/locales.coll.json
	{
		"Welcome!": {
			"he": "ברוכים הבאים!",
			"es": "Bienvenido!"
		},
		"I'm using %1": {
			"he": "אני משתמש ב%1",
			"es": "Estoy usando %1"
		},
		"Linux": {
			"he": "לינוקס"
		}
	}

	# in your app
	use Locale::Wolowitz;

	my $w = Locale::Wolowitz->new( './i18n' );

	print $w->loc('Welcome!', 'es'); # prints 'Bienvenido!'

	print $w->loc("I'm using %1", 'he', $w->loc('Linux', 'he')); # prints "אני משתמש בלינוקס"

	# you can also directly load data (useful if data is not in files, but say in database)
	$w->load_structure({
		hello => {
			he => 'שלום',
			fr => 'bonjour'
		}
	});

	print $w->loc('hello', 'he'); # prints "שלום"

=head1 DESCRIPTION

Locale::Wolowitz is a very simple text localization system. Yes, another
localization system.

Frankly, I never realized how to use the standard Perl localization systems
such as L<Locale::Maketext>, L<Gettext>, L<Data::Localize> or whatever.
It seems they are more meant to localize an application to the language
of the system on which its running, which isn't really what I need. Most of the
time, seeing as how I'm mostly writing web applications, I wish to localize
my applications/websites according to the user's wishes, not by the system.
For example, I may create a content management system where the user can
select the interface's language. Also, I grew to hate the standard .po
files, and thought using a JSON format might be more comfortable.

Locale::Wolowitz allows you to provide different languages to end-users of your
applications. To some extent, when writing RESTful web applications, this means
you can perform language negotiation with visitors (see
L<Content negotiation on Wikipedia|https://secure.wikimedia.org/wikipedia/en/w/index.php?title=Content_negotiation&oldid=367120431>).

Locale::Wolowitz works with JSON files. Each file can serve one or more languages.
When creating an instance of this module, you are required to pass a path
to a directory where your application's JSON localization files are present.
These are all loaded and merged into one big hash-ref (unless you tell the module
to only load a specific file), which is stored in memory. A file with only one
language has to be named <lang>.json (where <lang> is the name of the language,
you'd probably want to use the two-letter ISO 639-1 code). A file with multiple
languages must end with .coll.json (this requirement will probably be lifted in
the future).

The basic idea is to write your application in a base language, and use
the JSON files to translate text to other languages. For example, lets say
you're writing your application in English and translating it to Hebrew,
Spanish, and Dutch. You put Spanish and Dutch translations in one file,
and since everybody hates Israel, you put Hebrew translations alone.
The Spanish and Dutch file can look like this:

	# es_and_nl.coll.json
	{
		"Welcome!": {
			"es": "Bienvenido!",
			"nl": "Welkom!"
		},
		"I'm using %1": {
			"es": "Estoy usando %1",
			"nl": "Ik gebruik %1"
		},
		"Linux": {} // this line can also be missing entirely
	}

While the Hebrew file can look like this:

	# he.json
	{
		"Welcome!": "ברוכים הבאים!",
		"I'm using %1": "אני משתמש ב%1",
		"Linux": "לינוקס"
	}

When loading these files, Locale::Wolowitz internally merges the two files into
one structure:

	{
		"Welcome!" => {
			"es" => "Bienvenido!",
			"nl" => "Welkom!",
			"he" => "ברוכים הבאים!",
		},
		"I'm using %1" => {
			"es" => "Estoy usando %1",
			"nl" => "Ik gebruik %1",
			"he" => "אני משתמש ב%1",
		},
		"Linux" => {
			"he" => "לינוקס",
		}
	}

Notice the "%1" substrings above. This is a placeholder, just like in other
localization paradigms - they are replaced with content you provide, usually
dynamic content. In Locale::Wolowitz, placeholders are written with a percent
sign, followed by an integer, starting from 1 (e.g. %1, %2, %3). When passing
data for the placeholders, make sure you're passing scalars, or printable
objects, otherwise you'll encounter errors.

We can also see here that Spanish and Dutch have no translation for "Linux".
Since Linux is written "Linux" in these languages, they have no translation.
When attempting to translate a string that has no translation to the requested
language, or has no reference in the JSON files at all, the string is
simply returned as is (but placeholders will still be replaced as expected).

Say you write your application in English (and thus 'en' is your base
language). Since Locale::Wolowitz doesn't really know what your base language is,
you can translate texts within the same language. This is more useful when
you want to give some of your strings an identifier. For example:

	"copyrights": {
		"en": "Copyrights, 2010 Ido Perlmuter",
		"he": "כל הזכויות שמורות, 2010 עידו פרלמוטר"
	}

=head1 CONSTRUCTOR

=head2 new( [ $path / $filename, \%options ] )

Creates a new instance of this module. A path to a directory in
which JSON localization files exist, or a path to a specific localization
file, I<may> be supplied. If you pass a directory, all JSON localization files
in it will be loaded and merged as described above. If you pass one file,
only that file will be loaded.

Note that C<Locale::Wolowitz> will ignore dotfiles in the provided path (e.g.
hidden files, backups files, etc.).

A hash-ref of options can also be provided. The only option currently supported
is C<utf8>, which is on by default. If on, all JSON files are assumed to be in
UTF-8 character set and will be automatically decoded. Provide a false value
if your files are not UTF-8 encoded, for example:

	Locale::Wolowitz->new( '/path/to/files', { utf8 => 0 } );

=cut

sub new {
	my ($class, $path, $options) = @_;

	$options ||= {};
	$options->{utf8} = 1
		unless exists $options->{utf8};

	my $self = bless {}, $class;

	$self->{json} = JSON->new->relaxed;
	$self->{json}->utf8
		if $options->{utf8};

	$self->load_path($path)
		if $path;

	return $self;
}

=head1 OBJECT METHODS

=head2 load_path( $path / $filename )

Receives a path to a directory in which JSON localization files exist, or a
path to a specific localization file, and loads (and merges) the localization
data from the file(s). If localization data was already loaded previously,
the structure will be merged, with the new data taking precedence.

You can call this method and L<load_structure()|/"load_structure( \%structure, [ $lang ] )">
as much as you want, the data from each call will be merged with existing data.

=cut

sub load_path {
	my ($self, $path) = @_;

	croak "You must provide a path to localization directory."
		unless $path;

	$self->{locales} ||= {};

	my @files;

	if (-d $path) {
		# open the locales directory
		opendir(PATH, $path)
			|| croak "Can't open localization directory: $!";
	
		# get all JSON files
		@files = grep {/^[^.].*\.json$/} readdir PATH;

		closedir PATH
			|| carp "Can't close localization directory: $!";
	} elsif (-e $path) {
		my ($file) = ($path =~ m{/([^/]+)$})[0];
		$path = $`;
		@files = ($file);
	} else {
		croak "Path must be to a directory or a JSON file.";
	}

	# load the files
	foreach (@files) {
		# read the file's contents and parse it as json
		open(FILE, "$path/$_")
			|| croak "Can't open localization file $_: $!";
		local $/;
		my $json = <FILE>;
		close FILE
			|| carp "Can't close localization file $_: $!";

		my $data = $self->{json}->decode($json);

		# is this a one-lang file or a collection?
		if (m/\.coll\.json$/) {
			# this is a collection of languages
			foreach my $str (keys %$data) {
				foreach my $lang (keys %{$data->{$str}}) {
					$self->{locales}->{$str}->{$lang} = $data->{$str}->{$lang};
				}
			}
		} elsif (m/\.json$/) { # has to be true
			my $lang = $`;
			foreach my $str (keys %$data) {
				$self->{locales}->{$str}->{$lang} = $data->{$str};
			}
		}
	}

	return 1;
}

=head2 load_structure( \%structure, [ $lang ] )

Receives a hash-ref of localization data similar to that in the JSON files
and loads it into the object (possibly merging with existing data, if any).
If C<$lang> is supplied, a one-to-one structure will be assumed, like so:

	load_structure(
		{ "hello" => "שלום", "world" => "עולם" },
		'he'
	)

Or, if C<$lang> is not provided, the structure must be the multiple language
structure, like so:

	load_structure({
		"hello" => {
			"he" => "שלום",
			"fr" => "bonjour"
		},
		"world" => {
			"he" => "עולם",
			"fr" => "monde",
			"it" => "mondo"
		}
	})

You can call this method and L<load_path()|/"load_path( $path / $filename )">
as much as you want, the data from each call will be merged with existing data.

=cut

sub load_structure {
	my ($self, $struct) = @_;

	croak "The structure to load must be a hash-ref"
		unless $struct && ref $struct eq 'HASH';

	$self->{locales} ||= {};

	foreach (keys %$struct) {
		$self->{locales}->{$_} ||= {};
		foreach my $lang (keys %{$struct->{$_}}) {
			$self->{locales}->{$_}->{$lang} = $struct->{$_}->{$lang};
		}
	}

	return 1;
}

=head2 loc( $msg, $lang, [ @args ] )

Returns the string C<$msg>, translated to the requested language (if such
a translation exists, otherwise no traslation occurs). Any other parameters
passed to the method (C<@args>) are injected to the placeholders in the string
(if present).

If an argument is an array ref, it'll be replaced with
a recursive call to C<loc> with its elements, with the C<$lang>
argument automatically added.  In other
words, the following two statements are equivalent:

    print $w->loc("I'm using %1", 'he', $w->loc('Linux', 'he'));
    # same result as
    print $w->loc("I'm using %1", 'he', [ 'Linux' ]);


=cut

sub loc {
	my ($self, $msg, $lang, @args) = @_;

	return unless defined $msg; # undef strings are passed back as-is
	return $msg unless $lang;

	@args = map {
		ref $_ ne 'ARRAY' ?  $_ : do {
			my @args = @$_;
			splice @args, 1, 0, $lang;
			$self->loc( @args );
		}
	} @args;

	my $ret = $self->{locales}->{$msg} && $self->{locales}->{$msg}->{$lang} ? $self->{locales}->{$msg}->{$lang} : $msg;

	$ret =~ s/%(\d+)/$args[$1-1]/g;

	return $ret;
}

=head2 loc_for( $lang )

Returns a function ref that is like C<loc>, but with the C<$lang> curried away.

    use Locale::Wolowitz;

    my $w = Locale::Wolowitz->new( './i18n' );

    my $french_loc  = $w->loc_for('fr');
    my $german_loc  = $w->loc_for('de');

    print $french_loc->('Welcome!'); # equivalent to $w->loc( 'Welcome!', 'fr' )

=cut

sub loc_for {
	my( $self, $lang ) = @_;

	return sub {
		my $text = shift;
		$self->loc( $text, $lang, @_ );
	};
}


=head1 DIAGNOSTICS

The following exceptions are thrown by this module:

=over

=item C<< "You must provide a path to localization directory." >>

This exception is thrown if you haven't provided the C<new()> subroutine
a path to a localization file, or a directory of localization files. Read
the documentation for the C<new()> subroutine above.

=item C<< "Can't open localization directory: %s" and "Can't close localization directory: %s" >>

This exception is thrown if Locale::Wolowitz failed to open/close the directory
of the localization files. This will probably happen due to permission
problems. The error message should include the actual reason for the failure.

=item C<< "Path must be to a directory or a JSON file." >>

This exception is thrown if you passed a wrong value to the C<new()> subroutine
as the path to the localization directory/file. Either the path is wrong and thus
does not exist, or the path does exist, but is not a directory and not a file.

=item C<< "Can't open localization file %s: %s" and "Can't close localization file %s: %s" >>

This exception is thrown if Locale::Wolowitz fails to open/close a specific localization
file. This will usually happen because of permission problems. The error message
will include both the name of the file, and the actual reason for the failure.

=back

=head1 CONFIGURATION AND ENVIRONMENT

C<Locale::Wolowitz> requires no configuration files or environment variables.

=head1 DEPENDENCIES

C<Locale::Wolowitz> B<depends> on the following CPAN modules:

=over

=item * L<Carp>

=item * L<JSON::MaybeXS>

=back

C<Locale::Wolowitz> recommends L<Cpanel::JSON::XS> or L<JSON::XS> for faster
parsing of JSON files.

=head1 INCOMPATIBILITIES WITH OTHER MODULES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-Locale-Wolowitz@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Locale-Wolowitz>.

=head1 AUTHOR

Ido Perlmuter <ido@ido50.net>

=head1 LICENSE AND COPYRIGHT

Copyright 2017 Ido Perlmuter

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

1;
__END__
