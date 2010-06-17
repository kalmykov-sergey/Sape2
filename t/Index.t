use Test::More tests => 10;
BEGIN { use_ok('Sape::Index') };

is( qip_check('www.ntatm.ru/clauses/zastolie3.html'), 1, 'qip 1');
is( qip_check('130cmyk.ru'), 1, 'qip 2');
is( qip_check('5121.ru/?rub=85&page=2'), 0, 'qip 3');
is( yandex_check('http://www.portforum.ru/www-catalog/id/38'), 0, 'yandex 1');
is( yandex_check('portfoasdfasdfasm.ru/www-catalog/id/38.html'), 0, 'yandex 2');
ok( is_bad_donor('130cmyk.ru'), 'bad donor');
is( is_bad_donor('plarson.ru'), undef, 'plarson must be good donor');

SKIP: {
    eval{ require Yandex::XML};
    skip "Yandex::XML not installed", 2 if $@;
    is( xml_check('print-magazin.ru'), 1, 'xml 1'); 
    is( xml_check('portfoasdfasdfasm.ru/www-catalog/id/38.html'), 0, 'xml 2');
}


