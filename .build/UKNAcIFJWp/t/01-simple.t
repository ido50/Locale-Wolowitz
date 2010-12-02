#!perl -T

use strict;
use warnings;
use Test::More tests => 13;
use Wolowitz;
use utf8;

my $w = Wolowitz->new('t/i18n');
ok($w, 'Got a proper Wolowitz object');

is($w->loc('hey man', 'en'), 'hey man', 'en -> en [1]');

is($w->loc('what\'s up %1?', 'en', 'XO'), 'what\'s up XO?', 'en -> en [2]');

is($w->loc('generic', 'en'), 'bye bye', 'en -> en [3]');

is($w->loc('hey man', 'he'), 'היי בן-אדם', 'en -> he [1]');

is($w->loc('what\'s up %1?', 'he', 'XO'), 'מה נשמע XO?', 'en -> he [2]');

is($w->loc('generic', 'he'), 'ביי ביי', 'en -> he [3]');

is($w->loc('hey man', 'xo'), 'yo bro', 'en -> xo [1]');

is($w->loc('what\'s up %1?', 'xo', 'XO'), 'how\'s it hangin\' %1?', 'en -> xo [2]');

is($w->loc('generic', 'xo'), 'see ya', 'en -> xo [3]');

is($w->loc('hey man', 'rev_en'), 'nam yeh', 'en -> rev_en [1]');

is($w->loc('what\'s up %1?', 'rev_en', 'XO'), '?XO pu s\'tahw', 'en -> rev_en [2]');

is($w->loc('generic', 'rev_en'), 'eyb eyb', 'en -> rev_en [3]');

done_testing();
