use strict;
use Test::More tests => 8;

use FindBin;
use lib "$FindBin::Bin/lib";

use_ok('Catalyst::Test', 'TestApp');

my $response;
ok(($response = request("/test_render?template=specified_template.tx&param=parameterized"))->is_success, 'request ok');
is($response->content, "I should be a parameterized test in @{[TestApp->config->{name}]}", 'message ok');

my $message = 'Dynamic message';

# ok(($response = request("/test_msg?msg=$message"))->is_success, 'request ok');
# is($response->content, "$message", 'message ok');

$response = request("/test_render?template=non_existant_template.xt");

is (403, $response->code, 'request returned error');
like($response->content, qr/Xslate: LoadError: Cannot find 'non_existant_template\.xt'/, 'Error from non-existant-template');

is(
  request('/test_expose_methods')->content,
  'hello abc world zzz def arg ok',
  'Got expect content for expose_methods test',
);

is(
  request('/test_expose_methods_coerced')->content,
  'hello abc world zzz def arg ok',
  'Got expect content for test_expose_methods_coerced test',
);

is
    request('/test_header_footer')->content,
    'header! content! footer!',
    'Got header/footer',
;
