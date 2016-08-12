package openapi_deployapi4web;
use Dancer ':syntax';
use JSON;
use FindBin qw( $RealBin );
use File::Basename;
use YAML::XS;
use NS::Bone::Redis;
use Data::Dumper;
use NS::OpenAPI::Ctrl;
use NS::OpenAPI::Lock;
use NS::OpenAPI::Deploy;
use NS::OpenAPI::UMesg;

our $VERSION = '0.1';

set serializer => 'JSON';

any '/readme' => sub {
    template 'openapi_deployapi4web';
};

any '/mon' => sub { return 'ok'; };

any '/stat' => sub {
    my $param = params();
    my %res;
    eval{
        my $ctrl = NS::OpenAPI::Ctrl->new();
        my $lock = NS::OpenAPI::Lock->new();
        my $umesg  = NS::OpenAPI::UMesg->new();
        my $deploy = NS::OpenAPI::Deploy->new();

        my $name = $param->{name} 
                       ? ref $param->{name} ? $param->{name} 
                       : [ $param->{name} ] : $deploy->list();
        my %data;
        map{ $data{$_->[0]}{curr}{lock} = $_ }@{$lock->dump()};
        map{ push @{$data{$_->[1]}{curr}{ctrl}}, $_ }$ctrl->dump();
    
        map{ $data{$_->[0]}{logs}{$_->[1]} = $_->[2] }@{$umesg->deploystat()};
    
        for my $n ( @$name )
        {
            unless( $data{$n} ) { $res{$n} = +{}; next; }

            my %r;
            $r{logs} = $data{$n}{logs} 
                ? [ map{ [ $_, $data{$n}{logs}{$_}] }reverse sort keys %{$data{$n}{logs}} ]: [];
    
            if( $data{$n}{curr} && $data{$n}{curr}{lock} )
            {
                if( $data{$n}{curr}{ctrl} )
                {
                    ( $r{stat}, $r{info}  ) = 
                        ( 'block', join "#", map{ $_->[5] ||''}@{$data{$n}{curr}{ctrl}} );
                }
                else
                {
                    ( $r{stat}, $r{info} ) = 
                        ( 'running', "$data{$n}{curr}{lock}[1] : $data{$n}{curr}{lock}[2]" );
                }
            }
            else
            {
                ( $r{stat}, $r{info}  ) = ( 'done', '' );
            }
            $res{$n} = \%r;
    
        }
    };
    return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                 +{ stat => $JSON::true,  data => \%res };

};

any '/stat2' => sub {
    my $param = params();
    my %res;
    eval{
        my $ctrl = NS::OpenAPI::Ctrl->new();
        my $lock = NS::OpenAPI::Lock->new();
        my $umesg  = NS::OpenAPI::UMesg->new();
        my $deploy = NS::OpenAPI::Deploy->new();

        my $name = $param->{name} 
                       ? ref $param->{name} ? $param->{name} 
                       : [ $param->{name} ] : $deploy->list( $param->{user} );
        my %data;
        map{ $data{$_->[0]}{curr}{lock} = $_ }@{$lock->dump()};
        map{ push @{$data{$_->[1]}{curr}{ctrl}}, $_ }$ctrl->dump();
    
        map{ $data{$_->[0]}{logs}{$_->[1]} = $_->[2] }@{$umesg->deploystat()};
    
        for my $n ( @$name )
        {
            unless( $data{$n} ) { $res{$n} = +{}; next; }

            my %r;
            $r{logs} = $data{$n}{logs} 
                ? [ map{ [ $_, $data{$n}{logs}{$_}] }reverse sort keys %{$data{$n}{logs}} ]: [];
    
            if( $data{$n}{curr} && $data{$n}{curr}{lock} )
            {
                if( $data{$n}{curr}{ctrl} )
                {
                    ( $r{stat}, $r{info}  ) = 
                        ( 'block', join "#", map{ $_->[5] ||''}@{$data{$n}{curr}{ctrl}} );
                }
                else
                {
                    ( $r{stat}, $r{info} ) = 
                        ( 'running', "$data{$n}{curr}{lock}[1] : $data{$n}{curr}{lock}[2]" );
                }
            }
            else
            {
                ( $r{stat}, $r{info}  ) = ( 'done', '' );
            }
            $res{$n} = \%r;
    
        }
    };

my @r= ();

for my $n ( sort keys %res )
{
    my %t = ( name => $n, type => 'janus' ); 
    $t{stat} = $res{$n}{stat} ||= 'done';
    $t{info} = $res{$n}{info} ||= '';

    $t{strict} = -f "$RealBin/../data/openapi_deploy/$n/strict" ? 1 : 0;
    $t{child} = [];
    if( $res{$n}{logs} )
    {
        push @{$t{child}} , map{@$_}@{$res{$n}{logs}};
    }

    push @r, \%t;
}

my @rr = 
(
+{
  name => '公司',
  type => 'hermes',
  child =>[

    +{
         name => 'cloudops发布',
         type => 'hermes',
         child => [
             +{
             name => 'apps',
             type => 'hermes',
             child => \@r,
             },
         ],
     },
  ]
}
);

    return  $@ ? +{ stat => $JSON::false, info => $@ }: 
                 +{ stat => $JSON::true,  data => \@rr };

};


true;
