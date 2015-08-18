package NS::VSSH::OCMD::Help;
use strict;
use warnings;
use Carp;

use NS::Hermes;
use Term::ANSIColor qw(:constants :pushpop );
$Term::ANSIColor::AUTORESET = 1;

our $BTLEN = 30;

my %HELP =
(
    '.add' => '添加机器到当前的名字空间，支持range表达式，多个range可以同时add进去，用空格分开.
                 --- .add {%%seco} {==*==*??==*}',
    '.del' => '在当前空间删除机器列表，格式与 .add 类似.',
    '.load' => 'load 机器列表到当前空间（load的内容保持顺序）.
                 --- .load : 读取输入的内容（可以换行，输入结束标识符为‘END’）
                 --- .load file: 读取file的内容',
    '.sort' => '对当前的机器列表排序
                 --- .sort ：字符排序
                 --- .sort Num : 按照机器列表中的第Num个数字排序',
    '.block' => '剔除部分机器而不删除
                 --- .block i0{1~9}.se.bjdt.nices.net : 在当前空间剔除9台机器（如果存在的话）
                 --- .block *i0{1~3}.se.bjdt.nices.net : 强制锁定这3太机器
                 --- .block clear: 清除这个空间的block',

    '.filter' => '机器列表过滤器
                --- .filter /shjc/: 把包含shjc字符的机器过来出来
                --- .filter -/shjc/: 把包含shjc字符的机器去掉',
);

sub new
{
    my ( $this ) = @_;
    bless +{}, ref $this || $this;
}

sub get
{
    my ( $this, $name ) = @_;
    return $HELP{$name};
}

sub list
{
    return keys %HELP;
}

sub help
{
    my ( $this, $name ) = @_;
    print $HELP{$name} ? "$HELP{$name}\n" : "invalid option\n";
}


sub welcome
{
printf <<EOF;
                        _                          
          __      _____| | ___ ___  _ __ ___   ___ 
          \\ \\ /\\ / / _ \\ |/ __/ _ \\| '_ ` _ \\ / _ \
           \\ V  V /  __/ | (_| (_) | | | | | |  __/
            \\_/\\_/ \\___|_|\\___\\___/|_| |_| |_|\\___|
          
EOF

}

sub yesno
{
    while( 1 )
    {
        print "Are you sure you want to run this command [y/n]:";
        my $in = <STDIN>;
        next unless $in;
        return 1 if $in eq "y\n";
        return 0 if $in eq "n\n";
    }
}


sub result
{
    my ( $this, %re ) = @_;

    print "\n";
    print PUSHCOLOR RED ON_GREEN  "#" x $BTLEN, ' RESULT ', "#" x $BTLEN;
    print "\n";

    my $range = NS::Hermes->new( );
    print "=" x 68, "\n";
    map{

        my $c = YAML::XS::Load $_;
        printf "%s[", $range->load( $re{$_} )->dump;
        my $count = scalar @{$re{$_}};
        $c->{'exit'} ? print BOLD  RED $count : print BOLD GREEN $count;

        print "]:\n";
        print BOLD  GREEN "$c->{stdout}\n" if $c->{stdout};
        print BOLD  RED   "$c->{stderr}\n" if $c->{stderr};
        print "=" x 68, "\n";
    }keys %re;
}

1;
