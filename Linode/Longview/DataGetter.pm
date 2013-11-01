package Linode::Longview::DataGetter;

=head1 COPYRIGHT/LICENSE

Copyright 2013 Linode, LLC.  Longview is made available under the terms
of the Perl Artistic License, or GPLv2 at the recipients discretion.

=head2 Perl Artistic License

Read it at L<http://dev.perl.org/licenses/artistic.html>.

=head2 GNU General Public License (GPL) Version 2

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see http://www.gnu.org/licenses/

See the full license at L<http://www.gnu.org/licenses/>.

=cut

use strict;
use warnings;
use File::Basename;
use File::Find;

use Exporter 'import';
our @EXPORT = qw(get load_modules reload_modules run_order);

our $dep_info = {};
our $module_order = [];

use Linode::Longview::Util;

use FindBin;
my $module_path = "$FindBin::RealBin/Longview/DataGetter/";

sub run_order {
  return $module_order;
}

sub load_modules {
  $dep_info = {};
  $module_order = [];

  my @modules_on_disk;

  my $find_sub = sub {
    return if ! -f;
    return unless m/\.pm$/;
    my $module = $File::Find::name;
    $logger->info("Loading module $module");
    require $module;
    (my $rpath = $module)   =~ s|$module_path||;;
    (my $namepace = $rpath) =~ s|\.pm$||;
    $namepace =~ s|/|::|;
    {
      no strict 'refs';
      $dep_info->{$rpath} = ${"Linode::Longview::DataGetter::${namepace}::DEPENDENCIES"};
    }
  };
  find($find_sub,$module_path);
  my $resolve = resolve_deps($dep_info);
  print_unresolved($resolve->{unresolved}) if (keys %{$resolve->{unresolved}});
  $module_order = $resolve->{resolved};
  for (@{$module_order}){
    s|\.pm$||;
    s|/|::|;
  }
}

sub reload_modules {
  $logger->info("Reloading modules");
  delete $INC{$_} for grep {m|$module_path|} (keys %INC);
  load_modules();
}

sub resolve_deps {
  my $origGraph = shift;
  my $depGraph = {};
  #copy our dependency data so we don't wreck the original
  @{$depGraph->{$_}} = @{$origGraph->{$_}} for (keys %{$origGraph});
  my @resolved;
  my @unresolved = keys %{$depGraph};
  my @pending;
  #Move everything with no dependencies straight in to pending
  for my $child (keys %{$depGraph}) {
    if (scalar(@{$depGraph->{$child}})==0) {
      push @pending, $child;
      @unresolved = grep {$_ ne $child} @unresolved;
      delete $depGraph->{$child};
     }
  }
  #Move things from pending to resolved, preform book keeping on children as needed
  while (@pending) {
    my $current = shift @pending;
    push @resolved,$current;
    my @needBookKeeping = grep {grep {$_ eq $current} @{$depGraph->{$_}}} keys %{$depGraph};
    foreach my $child (@needBookKeeping) {
      #remove the resolved dependency from that child's list
      @{$depGraph->{$child}} = grep {$_ ne $current} @{$depGraph->{$child}};
      #if that child has no further dependencies move it in to pending
      unless (@{$depGraph->{$child}}){
        push @pending, $child;
        @unresolved = grep {$_ ne $child} @unresolved;
        delete $depGraph->{$child};
      }
    }
  }

  return {resolved=>\@resolved,unresolved=>$depGraph};
}

sub print_unresolved {
  my $unresolvedDeps = shift;
  $logger->error("Unresolved dependencies for the following modules:");
  for my $parent (keys %{$unresolvedDeps}) {
    my $broke_dep = "$parent => ";
    for my $child (@{$unresolvedDeps->{$parent}}) {
      $broke_dep .= "$child ";
    }
    $logger->error($broke_dep);
  }
}

sub get {
  my ($key,$dataref) = @_;
  return "Linode::Longview::DataGetter::${key}"->get($dataref);
}

1;
