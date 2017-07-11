use utf8;
package Koha::Schema::Result::CirculationRule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CirculationRule

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<circulation_rules>

=cut

__PACKAGE__->table("circulation_rules");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 branchcode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 categorycode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 itemtype

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 rule_name

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 rule_value

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "branchcode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "categorycode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "itemtype",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "rule_name",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "rule_value",
  { data_type => "varchar", is_nullable => 0, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<branchcode_2>

=over 4

=item * L</branchcode>

=item * L</categorycode>

=item * L</itemtype>

=back

=cut

__PACKAGE__->add_unique_constraint("branchcode_2", ["branchcode", "categorycode", "itemtype"]);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2017-07-03 15:35:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ok1AzADM8/wcfU9xS7LgNQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
