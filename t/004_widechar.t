use strict;
use Test::More tests => 3;

use FindBin;
use lib "$FindBin::Bin/lib";

use_ok('Catalyst::Test', 'TestApp');

my $response;
ok(($response = request("/test_render?template=widechar.tx&param=test"))->is_success, 'request ok');
is($response->content, "テストtest", 'wide characters ok');
