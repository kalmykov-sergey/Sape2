use Test::More 'no_plan';
BEGIN { use_ok('Sape::DB') };

ok( my $db = Sape::DB->_new(), 'connect is ok');
is( $db->_recreate_links_table(), 1, 'recreating links table' );
my $link1 = Sape::Link->new('plarson.ru/index.php');
my $link2 = Sape::Link->new('plarson.ru/index2.php');
is( $db->_insert_link($link1), 1, 'last_insert_id');
is( $db->_insert_link($link1), 1, 'repeat the same link - must not be inserted');
is( $db->_insert_link($link2), 2, 'last_insert_id 2');
$link2->{'link_id'} = 4;
is( $db->_delete_link($link2), 0, 'delete no rows using bad link_id');
$link2->{'link_id'} = 2;
is( $db->_delete_link($link2), 1, 'delete 1 row using link_id');
is( $db->_delete_link($link1), 1, 'delete 1 row without link_id');
#$db->_insert_link('plarson.ru/index.php');
my $f = sub{
    eval{$db->_insert_link('plarson.ru/index.php')};
    return $@;
}; 
like( &$f(), qr/is not a Link/, 'bad usage of _insert_link');

