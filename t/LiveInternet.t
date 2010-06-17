use Test::More tests => 4;
BEGIN { use_ok('Sape::Index::LiveInternet') };

is(live_internet_stats('plarson.ru')->{site}, "'plarson.ru'");
ok(live_internet_stats('plarson.ru')->{week_vis} > 0);
ok((not defined live_internet_stats('yandex.ru')), "yandex not registered in liveinternet :)");

