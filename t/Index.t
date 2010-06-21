use Test::More 'no_plan';#tests => 11;
BEGIN { use_ok('Sape::Index') };

is( qip_check('www.ntatm.ru/clauses/zastolie3.html'), 1, 'www with no http');
is( qip_check('130cmyk.ru'), 1, 'no www and no http');
is( qip_check('http://varintor.ru/unitazy-pissuary-bide20.html'), 0, 'better than pavel program');
is( qip_check('http://wow-server.aplus.by/articles/327-rukovodstvo-po-srazheniyu-s-ledi-smertnyj-shepot.html'), 1, 'long url');
is( qip_check('http://mediart.ru/tag/%C3'), 1, 'encoding like %C3');
is( qip_check('http://freedomink.org/index.php?newsid=68'), 0, 'many results, but no match');
is( qip_check('http://nuclearno.ru/text.asp?6352'), 1, 'lc url');
is( qip_check('http://cupofnews.ru/devices/Anonsirovan_telefon_Nokia_5800_Navigation_Edition/'), 1, 'uc, long and end-slash');

is( yandex_check('http://www.portforum.ru/www-catalog/id/38'), 0, 'yandex 1');
is( yandex_check('portfoasdfasdfasm.ru/www-catalog/id/38.html'), 0, 'yandex doesn\'t know non-existing sites');
ok( is_bad_donor('130cmyk.ru'), 'bad donor');
#is( is_bad_donor('plarson.ru'), undef, 'plarson must be a good donor');

SKIP: {
    eval{
        require Yandex::XML
    } or skip( "Yandex::XML not installed", 2);
    is( xml_check('print-magazin.ru'), 1, 'xml 1'); 
    is( xml_check('portfoasdfasdfasm.ru/www-catalog/id/38.html'), 0, 'xml 2');
}


