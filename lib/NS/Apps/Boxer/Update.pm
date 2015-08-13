package NS::Apps::Boxer::Update;

use strict;
use warnings;

use Carp;
use YAML::XS;
use NS::Apps::Route;

use Data::Dumper;
use Sys::Hostname;

sub new
{
    my ( $class, %self ) = @_;

    map{ die "$_ undef.\n" unless $self{$_} }qw( name route );

    bless \%self, ref $class || $class;
}

sub update
{
    my $this = shift;
    my ( $name, $version, $route, $force ) = @$this{qw( name version route force )};


    my $update = eval{
        YAML::XS::Load $route->get( boxer => $name )
    };

    die 'get update info fail.' unless $update && ref $update eq 'HASH';


    $update->{version} = ( $version eq 'rb@' && defined $update->{version} )
                         ? "$version$update->{version}"
                         : $version if defined $version;


    $update->{version} = $version if defined $version;

    YAML::XS::DumpFile \*STDOUT, $update;

    map{ die "$_ undef.\n" unless $update->{$_} }
        qw( LocalPath LocalLink version Depot );

    my $goto = $update->{version} =~ s/^goto@// ? 1 : 0;
    my $rollback = $update->{version} =~ s/^rb@// ? 1 : 0;
    die 'version syntax error.' unless length $update->{version};

    my ( $link, $keep ) = @$update{qw( LocalLink KeepPackage )};
    my $curr = readlink $link;
    $keep ||= 5;

    my $package = "$update->{LocalPath}/$update->{version}";

    if( $goto )
    {
        $package =~ s/\.tar.gz$|\.tar$//;
        $this->syscmd( "ln -fsn '$package' '$link'" );
    }
    elsif( $update->{version} =~ /\@patch$/ )
    {
        my $rb = "$link/.tmp4deploy/$update->{version}\@rb";
        if( $rollback )
        {
            return unless -e $rb;
            map
            {
                $this->syscmd( "cd '$link'", "patch -f -R $_ -p1 < '$package'" );
            }( '--dry-run', '' );

            $this->syscmd( "rm '$rb'" );
        }
        else
        {
            return if -e $rb;
            map
            {
                $this->syscmd( "cd '$link'","patch -f $_ -p1 < '$package'" );
            }( '--dry-run', '' );

            $this->syscmd(
                "cd '$link'",
                'mkdir -p .tmp4deploy',
                "cp '$package' '$rb'"
            );

            my @data = grep{ -f $_ && $_ =~ /\@patch$/ }glob "$update->{LocalPath}/*";
            map{ $this->syscmd( "rm -rf '$_'" ); }splice @data, 0, -$keep;
        }
    }
    elsif( $update->{version} =~ /\@inc$/ )
    {
        my $taropt = $update->{version} =~ /\.tar\.gz/ ? 'z' : '';

        my $rb = "$link/.tmp4deploy/$update->{version}";
        if( $rollback )
        {
             $this->syscmd(
                 "tar -${taropt}xvf '$rb' -C '$link' && rm -f '$rb'"
             ) if -e $rb;
        }
        else
        {
            return if -e $rb;
            die "no fail in inc package.\n" unless
                my @list = grep{ $_ !~ /\/$/ } map{ chomp $_; $_ }`tar -tf '$package'`;

            $this->syscmd(
                join " && ",
                "cd $link", "mkdir -p .tmp4deploy",
                "tar -${taropt}cvf '.tmp4deploy/.$update->{version}\@rb' -C . @list",
                "mv '.tmp4deploy/.$update->{version}\@rb' '.tmp4deploy/$update->{version}\@rb'"
            );

            my @data = grep{ -f $_ && $_ =~ /\@inc$/ }glob "$update->{LocalPath}/*";
            map{ $this->syscmd( "rm -rf '$_'" ); }splice @data, 0, -$keep;
        }

    }
    elsif( $update->{version} =~ /\@todo/ )
    {
        my $version = $update->{version};
        die "syntax err to \@todo\n" unless $version =~ s/\@todo:(.+)$/\@todo/;
        $version  =~ s/\.tar\@todo$|\.tar\.gz\@todo$/\@todo/

        my $todo = "$update->{LocalPath}/$version/$1";
        
        $this->syscmd( "chmod +x '$todo' && '$todo'" );

        my @data = grep{ -d $_ && $_ =~ /\@todo$/ }
            map{ unlink $_ if -f $_ ;$_}glob "$update->{LocalPath}/*";

        map{ $this->syscmd( "rm -rf '$_'" ); }splice @data, 0, -$keep;
    }
    else
    {
        my $pack = $package;
        $pack =~ s/\.tar\.gz$|\.tar$//;

        if( $rollback )
        {
            die "no file: $pack\@rb\n" unless -f "$pack\@rb";
            my $rb = eval{ YAML::XS::LoadFile "$pack\@rb"; };
            die "load \@rb fail:$@\n" if $@;

            die "\@rb syntax error.\n"
                unless $rb && ref $rb eq 'HASH' && $rb->{'link'} ;
            die "$rb->{'link'}: No such directory.\n" unless -e $rb->{'link'};
            $this->syscmd( "ln -fsn '$rb->{'link'}' '$link'" );
            print "update $link --> $rb->{'link'}\n";
        }
        else
        {
            if( $curr && $curr ne $pack )
            {
                eval{ YAML::XS::DumpFile "$pack\@rb", +{ 'link' => $curr } };
                return "dump \@rb fail:$@\n" if $@;
            }
            $this->syscmd( "ln -fsn '$pack' '$link'" );
            print "update $link --> $pack\n";
        }

        my @data = glob "$update->{LocalPath}/*";
        my @dir = grep{ -d $_ && $_ !~ /\@todo$/ }@data;
        map{ $this->syscmd( "rm -rf '$_'" ); }
            grep{ $_ ne $pack && $_ ne $curr } splice @dir, 0, -$keep;
        map{
             $this->syscmd( "rm -f '$_\@rb'" )
                 if( -f $_ && $_ =~ s/\@rb$// && ! -d $_ );
        }@data;

    }
}


sub syscmd
{
    my $this = shift;
    warn join " ", "boxer:", join( ' && ', @_ ), "\n"
        if $this->{verbose};
    return system( @_ ) ? die "boxer ERROR" : $this;
}

1;
__END__
