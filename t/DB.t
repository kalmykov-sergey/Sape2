use Test::More 'no_plan';
BEGIN { use_ok('Sape::DB') };

ok( my $db = Sape::DB->_new(), 'connect is ok');
is( $db->_recreate_links_table(), 1, 'recreating links table' );
my $link1 = Sape::Link->new('plarson.ru/index.php');
my $link2 = Sape::Link->new('plarson.ru/index2.php');
is( $db->_create_link($link1), 1, 'last_insert_id');
is( $db->_create_link($link1), 1, 'repeat the same link - must not be inserted');
is( $db->_create_link($link2), 2, 'last_insert_id 2');

