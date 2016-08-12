package openapi_deploymailauth;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use Data::Dumper;

our $VERSION = '0.1';
our $ROOT; 
BEGIN{ 
    $ROOT = "$RealBin/../data/openapi_deploymailauth";
    system "mdkir -p '$ROOT'" unless -d $ROOT;
};

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_deploymailauth';
};

any '/mon' => sub { return 'ok'; };

any '/:name' => sub {
    my $param = params();
    my ( $name, $data ) = @$param{qw( name data )};

    return +{ info => 'error data or ctrl', stat => $JSON::false } 
        unless $data && ( $name eq 'i' || $name eq 'o' || $name eq 's' );

    return +{ info => 'novaliddata', stat => $JSON::false } 
        unless my @data = grep{ /^\d{10}[a-z0-9\.]{32,35}$/ }split /,/, $data;

    if( $name eq 'i' )
    {
        my $stat = 0;
        map{ $stat = 1 if system "touch '$ROOT/$_'" }@data;
    
        return +{ stat =>  $stat ? $JSON::false : $JSON::true };
    }
    elsif( $name eq 'o' )
    {
        my %data;
        map{ $data{$_} = 1 if -f "$ROOT/$_" }@data;
        return +{ stat => $JSON::true, data => [ keys %data] };
    }
    else
    {
        return '<html>
<body>
<TABLE>
  <TR>
    <TD>
      <form  action="i" method="get">
      <input type="hidden" name="data" value="'.$data.'.ko">
      <input type="submit" style="color:red" value="检测未通过">
      </form>
    </TD>
    <TD>
      <form  action="i" method="get">
      <input type="hidden" name="data" value="'.$data.'.ok">
      <input type="submit" style="color:green" value="通过">
      </form>
    </TD>
  </TR>
 </TABLE>
</body>
</html>';
    }
};

true;
