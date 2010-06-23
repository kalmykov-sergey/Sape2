use Test::More 'no_plan';
BEGIN { use_ok('Sape::Link') };

ok( $link = Sape::Link->new('plarson.ru/index.php'), 'new from url');
ok( $link = Sape::Link->new({'site_url' => 'plarson.ru', 'page_uri' => '/index.php'}), 'new from hashref');
is( $link->site_url, 'plarson.ru', 'host' );
is( $link->page_uri, '/index.php', 'page' );