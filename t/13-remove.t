use Test::More;
use Doubly::Linked;

ok(my $linked_list = Doubly::Linked->new());
=pod
ok($linked_list->insert_at_start(1));
ok($linked_list = $linked_list->insert_at_end(2));
ok($linked_list->insert_after(3));

ok($linked_list = $linked_list->start);

is($linked_list->is_start, 1);

is($linked_list->data, 1);

is($linked_list->next->data, 2);
is($linked_list->next->next->data, 3);

is($linked_list->next->remove, 2);

is($linked_list->next->data, 3);

is($linked_list->next->remove, 3);

is($linked_list->next, undef);

is($linked_list->remove, 1);

is($linked_list->data, undef);

is($linked_list->remove, undef);
=cut

ok($linked_list = Doubly::Linked->new());

ok($linked_list->insert_at_start(1));
ok($linked_list = $linked_list->insert_at_end(2));
ok($linked_list->insert_after(3));

ok($linked_list = $linked_list->start);

is($linked_list->is_start, 1);

is($linked_list->data, 1);


ok($linked_list = $linked_list->remove());
ok($linked_list = $linked_list->remove());
ok($linked_list = $linked_list->remove());

done_testing();

