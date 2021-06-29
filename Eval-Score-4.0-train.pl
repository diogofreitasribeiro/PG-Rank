#!
# author: Jun Xu and Tie-Yan Liu
# modified by Jun Xu, March 3, 2009 (for Letor 4.0)
use strict;

#hash table for NDCG,
my %hsNdcgRelScore = (  "2", 3,
                        "1", 1,
                        "0", 0,
                    );

my %hsPrecisionRel = ("2", 1,
                      "1", 1,
                      "0", 0
                );

my $iMaxPosition = 10;

my $argc = $#ARGV+1;
if($argc != 4)
{
		exit -1;
}
my $fnFeature = $ARGV[0];
my $fnPrediction = $ARGV[1];
my $fnResult = $ARGV[2];
my $flag = $ARGV[3];
if($flag != 1 && $flag != 0)
{
	exit -1;
}

my %hsQueryDocLabelScore = ReadInputFiles($fnFeature, $fnPrediction);
my %hsQueryEval = EvalQuery(\%hsQueryDocLabelScore);
OuputResults($fnResult, %hsQueryEval);


sub OuputResults
{
    my ($fnOut, %hsResult) = @_;
    my @qids = sort{$a <=> $b} keys(%hsResult);
    my $numQuery = @qids;
    my @prec;
    my $map = 0;
    for(my $i = 0; $i < $#qids + 1; $i ++)
    {
        my $qid = $qids[$i];
        my @pN = @{$hsResult{$qid}{"PatN"}};
        my $map_q = $hsResult{$qid}{"MAP"};
        if ($flag == 1)
        {
            #print FOUT "$qid\t";
        }
        for(my $iPos = 0; $iPos < $iMaxPosition; $iPos ++)
        {
            $prec[$iPos] += $pN[$iPos];
        }
        $map += $map_q;
    }
    for(my $iPos = 0; $iPos < $iMaxPosition; $iPos ++)
    {
        $prec[$iPos] /= ($#qids + 1);
    }
    $map /= ($#qids + 1);
    print sprintf("%.4f;", $map);
    
    my @ndcg;
    my $meanNdcg = 0;
    for(my $i = 0; $i < $#qids + 1; $i ++)
    {
        my $qid = $qids[$i];
        my @ndcg_q = @{$hsResult{$qid}{"NDCG"}};
        my $meanNdcg_q = $hsResult{$qid}{"MeanNDCG"};
        if ($flag == 1)
        {
            #print FOUT "$qid\t";
        }
        for(my $iPos = 0; $iPos < $iMaxPosition; $iPos ++)
        {
            $ndcg[$iPos] += $ndcg_q[$iPos];
        }
        $meanNdcg += $meanNdcg_q;
    }
    for(my $iPos = 0; $iPos < $iMaxPosition; $iPos ++)
    {
        $ndcg[$iPos] /= ($#qids + 1);
    }
    $meanNdcg /= ($#qids + 1);
    print sprintf("%.4f", $meanNdcg);
}

sub EvalQuery
{
    my $pHash = $_[0];
    my %hsResults;
    
    my @qids = sort{$a <=> $b} keys(%$pHash);
    for(my $i = 0; $i < @qids; $i ++)
    {
        my $qid = $qids[$i];
        my @tmpDid = sort{$$pHash{$qid}{$a}{"lineNum"} <=> $$pHash{$qid}{$b}{"lineNum"}} keys(%{$$pHash{$qid}});
        my @docids = sort{$$pHash{$qid}{$b}{"pred"} <=> $$pHash{$qid}{$a}{"pred"}} @tmpDid;
        my @rates;

        for(my $iPos = 0; $iPos < $#docids + 1; $iPos ++)
        {
            $rates[$iPos] = $$pHash{$qid}{$docids[$iPos]}{"label"};
        }

        my $map  = MAP(@rates);
        my @PAtN = PrecisionAtN($iMaxPosition, @rates);    
        my @Ndcg = NDCG($#rates + 1, @rates);
        my $meanNdcg = 0;
        for(my $iPos = 0; $iPos < $#Ndcg + 1; $iPos ++)
        {
            $meanNdcg += $Ndcg[$iPos];
        }
        $meanNdcg /= ($#Ndcg + 1);
        
        
        @{$hsResults{$qid}{"PatN"}} = @PAtN;
        $hsResults{$qid}{"MAP"} = $map;
        @{$hsResults{$qid}{"NDCG"}} = @Ndcg;
        $hsResults{$qid}{"MeanNDCG"} = $meanNdcg;

    }
    return %hsResults;
}

sub ReadInputFiles
{
    my ($fnFeature, $fnPred) = @_;
    my %hsQueryDocLabelScore;
    
    if(!open(FIN_Feature, $fnFeature))
	{
		exit -2;
	}
	if(!open(FIN_Pred, $fnPred))
	{
		exit -2;
	}

    my $lineNum = 0;
    while(defined(my $lnFea = <FIN_Feature>))
    {
        $lineNum ++;
        chomp($lnFea);
        my $predScore = <FIN_Pred>;
        if (!defined($predScore))
        {
             exit -2;
        }
        chomp($predScore);

        if ($lnFea =~ m/^(\d+) qid\:([^\s]+).*?\#docid = ([^\s]+) inc = ([^\s]+) prob = ([^\s]+)/)
        {
            my $label = $1;
            my $qid = $2;
            my $did = $3;
            my $inc = $4;
            my $prob= $5;
            $hsQueryDocLabelScore{$qid}{$did}{"label"} = $label;
            $hsQueryDocLabelScore{$qid}{$did}{"inc"} = $inc;
            $hsQueryDocLabelScore{$qid}{$did}{"prob"} = $prob;
            $hsQueryDocLabelScore{$qid}{$did}{"pred"} = $predScore;
            $hsQueryDocLabelScore{$qid}{$did}{"lineNum"} = $lineNum;
        }
        else
        {
            exit -2;
        }
    }
    close(FIN_Feature);
    close(FIN_Pred);
    return %hsQueryDocLabelScore;
}


sub PrecisionAtN
{
    my ($topN, @rates) = @_;
    my @PrecN;
    my $numRelevant = 0;

    for (my $iPos = 0; $iPos < $topN; $iPos ++)
    {
        my $r;
        if ($iPos < $#rates + 1)
        {
            $r = $rates[$iPos];
        }
        else
        {
            $r = 0;
        }
        $numRelevant ++ if ($hsPrecisionRel{$r} == 1);
        $PrecN[$iPos] = $numRelevant / ($iPos + 1);
    }
    return @PrecN;
}

sub MAP
{
    my @rates = @_;

    my $numRelevant = 0;
    my $avgPrecision = 0.0;
    for(my $iPos = 0; $iPos < $#rates + 1; $iPos ++)
    {
        if ($hsPrecisionRel{$rates[$iPos]} == 1)
        {
            $numRelevant ++;
            $avgPrecision += ($numRelevant / ($iPos + 1));
        }
    }
    return 0.0 if ($numRelevant == 0);

    return $avgPrecision / $numRelevant;
}

sub DCG
{
    my ($topN, @rates) = @_;
    my @dcg;
    
    $dcg[0] = $hsNdcgRelScore{$rates[0]};

    for(my $iPos = 1; $iPos < $topN; $iPos ++)
    {
        my $r;
        if ($iPos < $#rates + 1)
        {
            $r = $rates[$iPos];
        }
        else
        {
            $r = 0;
        }
        if ($iPos < 2)
        {
            $dcg[$iPos] = $dcg[$iPos - 1] + $hsNdcgRelScore{$r};
        }
        else
        {
            $dcg[$iPos] = $dcg[$iPos - 1] + ($hsNdcgRelScore{$r} * log(2.0) / log($iPos + 1.0));
        }
    }
    return @dcg;
}
sub NDCG
{
    my ($topN, @rates) = @_;
    my @ndcg;
    my @dcg = DCG($topN, @rates);
    my @stRates = sort {$hsNdcgRelScore{$b} <=> $hsNdcgRelScore{$a}} @rates;
    my @bestDcg = DCG($topN, @stRates);
    
    for(my $iPos =0; $iPos < $topN && $iPos < $#rates + 1; $iPos ++)
    {
        $ndcg[$iPos] = 0;
        $ndcg[$iPos] = $dcg[$iPos] / $bestDcg[$iPos] if ($bestDcg[$iPos] != 0);
    }
    return @ndcg;
}

