# <@LICENSE>
# Copyright 2004 Apache Software Foundation
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# </@LICENSE>

package Mail::SpamAssassin::Plugin::URIEval;

use Mail::SpamAssassin::Plugin;
use Mail::SpamAssassin::Logger;

use strict;
use warnings;
use bytes;

use vars qw(@ISA);
@ISA = qw(Mail::SpamAssassin::Plugin);

# constructor: register the eval rule
sub new {
  my $class = shift;
  my $mailsaobject = shift;

  # some boilerplate...
  $class = ref($class) || $class;
  my $self = $class->SUPER::new($mailsaobject);
  bless ($self, $class);

  # the important bit!
  $self->register_eval_rule("check_domain_ratio");
  $self->register_eval_rule("check_for_http_redirector");
  $self->register_eval_rule("check_https_ip_mismatch");

  return $self;
}

###########################################################################

sub check_domain_ratio {
  my ($self, $pms, $body, $ratio) = @_;
  my $length = (length(join('', @{$body})) || 1);
  if (!defined $pms->{uri_domain_count}) {
    $pms->get_uri_list();
  }
  return 0 if !defined $pms->{uri_domain_count};
  return (($pms->{uri_domain_count} / $length) > $ratio);
}

sub check_for_http_redirector {
  my ($self, $pms) = @_;

  foreach ($pms->get_uri_list()) {
    while (s{^https?://([^/:\?]+).+?(https?:/{0,2}?([^/:\?]+).*)$}{$2}) {
      my ($redir, $dest) = ($1, $3);
      foreach ($redir, $dest) {
	$_ = Mail::SpamAssassin::Util::uri_to_domain(lc($_)) || $_;
      }
      next if ($redir eq $dest);
      dbg("eval: redirect: found $redir to $dest, flagging");
      return 1;
    }
  }
  return 0;
}

###########################################################################

sub check_https_ip_mismatch {
  my ($self, $pms) = @_;

  while (my($k,$v) = each %{$pms->{html}->{uri_detail}}) {
    next if ($k !~ m%^https?:/*(?:[^\@/]+\@)?\d+\.\d+\.\d+\.\d+%i);
    foreach (@{$v->{anchor_text}}) {
      next if (m%^https:/*(?:[^\@/]+\@)?\d+\.\d+\.\d+\.\d+%i);
      if (m%https:%i) {
	keys %{$self->{html}->{uri_detail}}; # resets iterator, bug 4829
	return 1;
      }
    }
  }

  return 0;
}

1;
