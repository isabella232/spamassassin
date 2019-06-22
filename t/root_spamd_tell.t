#!/usr/bin/perl -T

use lib '.'; use lib 't';
use SATest; sa_t_init("root_spamd_tell");

use Test::More;
plan skip_all => "root tests disabled" unless conf_bool('run_root_tests');
plan skip_all => "not running tests as root" unless eval { ($> == 0); };
plan tests => 6;

# ---------------------------------------------------------------------------

%patterns = (
q{ Message successfully } => 'learned',
);

# run spamc as unpriv uid
$spamc = "sudo -u nobody $spamc";

# remove these first
unlink('log/user_state/bayes_seen.dir');
unlink('log/user_state/bayes_toks.dir');

# ensure it is writable by all
use File::Path; mkpath("log/user_state"); chmod 01777, "log/user_state";

# use SDBM so we do not need DB_File
tstlocalrules ("
        bayes_store_module Mail::SpamAssassin::BayesStore::SDBM
");

ok(start_spamd("-L --allow-tell"));

ok(spamcrun("-lx -L ham < data/spam/001", \&patterns_run_cb));
ok_all_patterns();

ok(stop_spamd());

# ensure these are not owned by root
ok check_owner('log/user_state/bayes_seen.dir');
ok check_owner('log/user_state/bayes_toks.dir');

sub check_owner {
  my $f = shift;
  my @stat = stat $f;

  print "stat($f) = ".join(', ', @stat)."\n";

  if (!defined $stat[1]) {
    warn "no stat for $f";
    return 0;
  }
  elsif ($stat[4] == 0) {
    warn "stat for $f: owner is root";
    return 0;
  }
  else {
    return 1;
  }
}
