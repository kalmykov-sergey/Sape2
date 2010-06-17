use Test::More tests => 5;
BEGIN { use_ok('Sape::Index::Alexa') };

is( alexa_stats('portfoasdfasdfasdfasdfasdfrum.ru'), 0, "no stats for nonexisting url");
is( alexa_stats('google.com'), 1, "google still has first alexa rank");
ok( alexa_stats('plarson.ru') < 5_500_000, "and plarson has rank less than 6 mil");
my %stats = alexa_stats('fgroup.ru');
ok( ($stats{rank} == 0 and $stats{sites} > 0), "there exists some sites with no rank but with some backlinksites");
