package NS::Util::AppsDeploy;

use strict;
use warnings;

use Carp;
use YAML::XS;
use Data::Dumper;

use File::Basename;
use Digest::MD5;

sub new
{
    my ( $class, %self ) = @_;

    confess "data undef.\n" unless $self{data};
    map{ die "$_ undef" unless $self{data}{ctrl}{$_} }qw( repo path link );

    bless \%self, ref $class || $class;
}

sub stage  
{
    my ( $this, %param ) = @_;
    my $data = $param{data};
    my ( $repo, $path ) = @$data{qw( repo path )};

    my $basename = basename $repo;
    $path = File::Spec->join( $path, $basename );
    my ( $info, $succ ) = ( "$path/info", "$path/info/stage.succ" );

    return if -e "$path/$basename" && -f $succ;

    $this->syscmd( 'stage' => "rm '$succ'") if -f $succ;
    $this->syscmd( 'stage' => "mkdir -p '$info'") unless -d $info; 

    my $limit = $param{mark} 
        ? $repo =~ m#^http://# ? "--limit-rate=$param{mark}k": "--bwlimit $param{mark}" : '';

    $repo =~ m#^http://#
        ? $this->syscmd( 'stage' => "wget $limit -q -O '$path/$basename' '$repo'")
        : $this->syscmd( 'stage' => "rsync -a $limit '$repo' '$path'");

    $this->syscmd( 'stage' => "touch '$succ'") unless -f $succ;
}

sub explain
{
    my ( $this, %param ) = @_;

    my $data = $param{data};
    my ( $repo, $path, $link ) = @$data{qw( repo path link )};

    my $tmp = my $basename = basename $repo;
    $path = File::Spec->join( $path, $basename );
    my $pack = File::Spec->join( $path, $basename );

    $this->stage( %param, mark => undef ) unless -e $pack && "$path/info/stage.succ";
    my $succ = "$path/info/explain.succ";

    my $packtype = $tmp =~ s/\.tar\.gz$// ? 'tar.gz' : $tmp =~ s/\.tar$// ? 'tar' : 'raw';
    my $datatype = $tmp =~ /\.patch$/ ? 'patch' : $tmp =~ /\.inc$/ ? 'inc' : 'full';

    my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9, qw( ! @ $ % ^ & *) );
    my $md5 = Digest::MD5->new->add(
                join("", @chars[ map { rand @chars } ( 1 .. 128 ) ] ) . time
                       )->hexdigest;
 
    if( $datatype eq 'full' )
    {
        return if -f $succ && ( -f "$path/data" || ( -d "$path/data" && -l "$path/data/.deploy_id" ) );
   
        $this->syscmd( 'explain' => "ln -fsn '$md5' '$path/data/.deploy_id'")
            if ! -l "$path/data/.deploy_id" && -d "$path/data";

        return if -f $succ && ( -f "$path/data" || ( -d "$path/data" && -l "$path/data/.deploy_id" ) );
    }
    else
    {
        return if -f $succ && -e "$path/data";
    }

    $this->syscmd( 'explain' => "rm -f '$succ'") if -f $succ;

    if( $packtype eq 'tar.gz' || $packtype eq 'tar' )
    {
        $this->syscmd( 'explain' => "mkdir '$path/data'") unless -d "$path/data";
        my $opt = $packtype eq 'tar.gz' ? 'z' : '';
        $this->syscmd( 'explain' => "tar -${opt}xvf '$pack' -C '$path/data'");
    }
    else
    {
        -f $pack 
            ? $this->syscmd( 'explain' => "rsync '$pack' '$path/data'")
            : $this->syscmd( 'explain' => "rsync -a '$pack/' '$path/data/'");
    }


    $this->syscmd( 'explain' => "ln -fsn '$md5' '$path/data/.deploy_id'") 
        if $datatype eq 'full'&& -d "$path/data" && !-l "$path/data/.deploy_id";

    $this->syscmd( 'explain' => "touch '$succ'") unless -f $succ;
}

sub deploy
{
    my ( $this, %param ) = @_;
    my $data = $param{data};
    my ( $repo, $path, $link ) = @$data{qw( repo path link )};

    my $count = $param{mark} ||= 5;

    my $tmp = my $basename = basename $repo;
    $path = File::Spec->join( $path, $basename );
    my $pack = File::Spec->join( $path, $basename );

    my $packtype = $tmp =~ s/\.tar\.gz$// ? 'tar.gz' : $tmp =~ s/\.tar$// ? 'tar' : 'raw';
    my $datatype = $tmp =~ /\.patch$/ ? 'patch' : $tmp =~ /\.inc$/ ? 'inc' : 'full';


    if( $datatype eq 'full' )
    {
        $this->explain( %param, mark => undef ) 
            unless -f "$path/info/explain.succ" 
                && ( -f "$path/data" || ( -d "$path/data" && -l "$path/data/.deploy_id" ) );
    }
    else
    {
        $this->explain( %param, mark => undef ) unless -f  "$path/info/explain.succ" && -e "$path/data";
    }

    $this->syscmd( 'deploy' => "touch '$path/info/$datatype'") unless -f "$path/info/$datatype";

    if( $datatype eq 'patch' )
    {
        die "This patch is not a single file\n" unless -f "$path/data";

        my $currlink = readlink $link;
        die "The current full package does not take effect\n" unless $currlink && -d $currlink;

        my $deployid = readlink "$currlink/.deploy_id";
        die "Did not find deployid\n" unless $deployid && $deployid =~ /^[a-z0-9]{32}$/;

        my $privatepath = "$path/info/$deployid";

        unless( -f "$privatepath/done" )
        {
            $this->syscmd( 'deploy' => "mkdir -p '$privatepath/backup'") unless -d "$privatepath/backup";
            $this->syscmd( 'deploy' => "patch -f -p1 --dry-run < '$path/data'");
            $this->syscmd( 'deploy' => "patch -f -p1 < '$path/data'");
            $this->syscmd( 'deploy' => "touch '$privatepath/done'");
        }
 
    }
    elsif( $datatype eq 'inc' )
    {
        die "This inc is not a directory\n" unless -d "$path/data";

        my $currlink = readlink $link;
        die "The current full package does not take effect\n" unless $currlink && -d $currlink;

        my $deployid = readlink "$currlink/.deploy_id";
        die "Did not find deployid\n" unless $deployid && $deployid =~ /^[a-z0-9]{32}$/;

        my $privatepath = "$path/info/$deployid";

        unless( -f "$privatepath/done" )
        {
            $this->syscmd( 'deploy' => "mkdir -p '$privatepath/backup'") unless -d "$privatepath/backup";
            $this->syscmd( 'deploy' => "rsync -a -b --backup-dir '$privatepath/backup' '$path/data/' '$currlink/'");
            $this->syscmd( 'deploy' => "touch '$privatepath/done'");
        }
    }
    else
    {
         my $currlink = readlink $link;
         my $rollback = "$path/info/rollback";
         my $rolllink = readlink $rollback;

         $this->syscmd( 'deploy' => "ln -fsn '$currlink' '$rollback'" )
             if $currlink && (( $rolllink && $currlink ne "$path/data" && $rolllink ne $currlink ) || !$rolllink );

         $this->syscmd( 'deploy' => "ln -fsn '$path/data' '$link'" )
             unless $currlink && $currlink eq "$path/data";
    }

    my %path = map{ $_ => ( stat $_ )[10] }glob "$data->{path}/*/info/$datatype";

    delete $path{"$path/info/$datatype"};
    my @path = sort{ $path{$a} <=> $path{$b} }keys %path;
    while( @path > $count )
    {
        my $p = shift @path;
        $p =~ s#/info/$datatype$##;
        $this->syscmd( 'deploy' => "rm -rf '$p'");
    }

};

sub rollback
{
    my ( $this, %param ) = @_;

    my $data = $param{data};
    my ( $repo, $path, $link ) = @$data{qw( repo path link )};

    my $tmp = my $basename = basename $repo;
    $path = File::Spec->join( $path, $basename );
    my $pack = File::Spec->join( $path, $basename );

    die "no package $pack, need stage.\n" unless -e $pack;

    $tmp =~ s/\.tar$// unless $tmp =~ s/\.tar\.gz$//;

    my $datatype = $tmp =~ /\.patch$/ ? 'patch' : $tmp =~ /\.inc$/ ? 'inc' : 'full';

    if( $datatype eq 'patch' )
    {
        die "This patch is not a single file\n" unless -f "$path/data";

        my $currlink = readlink $link;
        die "The current full package does not take effect\n" unless $currlink && -d $currlink;

        my $deployid = readlink "$currlink/.deploy_id";
        die "Did not find deployid\n" unless $deployid && $deployid =~ /^[a-z0-9]{32}$/;

        my $privatepath = "$path/info/$deployid";

        die "no the backup to rollback\n" unless  -f "$privatepath/done";

        $this->syscmd( 'deploy' => "patch -f -R -p1 --dry-run < '$path/data'");
        $this->syscmd( 'deploy' => "patch -f -R -p1 < '$path/data'");
 
        $this->syscmd( 'deploy' => "rm -rf '$privatepath'");
    }
    elsif( $datatype eq 'inc' )
    {
        die "This inc is not a directory\n" unless -d "$path/data";

        my $currlink = readlink $link;
        die "The current full package does not take effect\n" unless $currlink && -d $currlink;

        my $deployid = readlink "$currlink/.deploy_id";
        die "Did not find deployid\n" unless $deployid && $deployid =~ /^[a-z0-9]{32}$/;

        my $privatepath = "$path/info/$deployid";

        die "no the backup to rollback\n" unless  -f "$privatepath/done";

        $this->syscmd( 'deploy' => "rsync -a '$privatepath/backup/' '$path/data/'");
        $this->syscmd( 'deploy' => "rm -rf '$privatepath'");
    }
    else
    {
         my $currlink = readlink $link;
         my $rolllink = readlink "$path/info/rollback";
         die "no rollback data\n" unless $rolllink && -e $rolllink;

         $this->syscmd( 'deploy' => "ln -fsn '$rolllink' '$link'" )
             unless $currlink && $currlink eq $rolllink;
    }
}

sub show
{
    my ( $this, %param ) = @_;
    my $data = $param{data};
    my ( $repo, $path, $link ) = @$data{qw( repo path link )};

    my $tmp = my $basename = basename $repo;

    my @pack = glob "$path/*";
    $path = File::Spec->join( $path, $basename );

    my $packtype = $tmp =~ s/\.tar\.gz$// ? 'tar.gz' : $tmp =~ s/\.tar$// ? 'tar' : 'raw';
    my $datatype = $tmp =~ /\.patch$/ ? 'patch' : $tmp =~ /\.inc$/ ? 'inc' : 'full';

    my %data;
    if( $data{current} = readlink $link )
    {
        $data{rollback} = readlink "$data{current}/../info/rollback";
        $data{rollback} = $data{rollback} 
            ? -e $data{rollback} ? $data{rollback}:"nvalid link":"no link";

        if( $datatype eq 'patch' ||  $datatype eq 'inc' )
        {
            my $deployid = readlink "$data{currlink}/.deploy_id";
            unless( $deployid && $deployid =~ /^[a-z0-9]{32}$/ )
            {
                $data{error} = "Did not find deployid";
            }
            else
            {
                $data{$datatype} = -f "$path/info/$deployid/done"
                    ? "$datatype is in effect" : "$datatype is not used";
            }
        }
    }
    else { $data{error} = "Current link is empty"; }

    map{ print "$_: $data{$_}\n" if $data{$_}; }qw( current rollback patch inc error );
    map{ printf "package: %s\n", basename $_; }@pack;
};

our %ctrl =
(
    stage => sub { shift->stage(@_); },
    explain => sub { shift->explain(@_); },
    deploy => sub { shift->deploy(@_); },
    rollback => sub { shift->rollback(@_); },
    show => sub { shift->show(@_); },
);

sub do
{
    my ( $this, %param ) = @_;
    my $data = $this->{data};
    my ( $macro, $ctrl ) = @param{qw( macro ctrl )};

    my %macro = ( %$macro, %{$data->{macro}});

    my %data = %{$data->{ctrl}};
    for my $t ( qw(  link repo path ) )
    {
        map{ $data{$t} =~ s/\$macro{$_}/$macro{$_}/g; }keys %macro;
    }
    unless( @$ctrl )
    {
        print YAML::XS::Dump $this->{verbose} ? \%data: $data;
        return;
    }
    for my $ctrl ( @$ctrl )
    {
        my $mark;
        ( $ctrl, $mark ) = ( $1, $2 ) if $ctrl =~ /^(.+):(\d+)$/;

        die "no command $ctrl\n" unless $ctrl{$ctrl};
        &{$ctrl{$ctrl}}( $this, data => \%data, macro => \%macro, mark => $mark );
    }
}

sub syscmd
{
    my ( $this, $ctrl ) = splice @_, 0, 2;

    my $show = join " ", "[$ctrl]:", @_;
    print( "$show\n" ) and return if $this->{print};

    warn "$show\n" if $this->{verbose};
    return system( @_ ) ? die "run $ctrl ERROR\n" : $this;
}

1;
__END__
