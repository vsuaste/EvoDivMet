#!/usr/bin/perl
use strict;
use warnings;

#----------------SUBS--------------------------
sub clusterizeAndAssignColor;
sub printClusters;
sub readColorsCluster;
#----------------MAIN--------------------------

my $blast_file_name = $ARGV[0];
my $out_name = $ARGV[1];
my $special_org = $ARGV[2];
my $e_value = $ARGV[3];

my $ref_hash_id_color = clusterizeAndAssingColor($blast_file_name);
printClusters($out_name, $ref_hash_id_color);
makeClusterFunction($out_name."/clusters.cl",  $special_org);
print "**********SPECIAL ORG: $special_org \n";
#my $clusters_file = $ARGV[0];

#my $ref_hash = readColorsCluster($clusters_file);
#foreach my $job_id(keys %$ref_hash)
#{
#  foreach my $org(keys %{$ref_hash->{$job_id}})
#  {
#    print "$job_id $org  $ref_hash->{$job_id}->{$org} \n";
#  }
#}

#-----------SUBS DEFINITION--------------------

sub clusterizeAndAssingColor{
  my $blast_file_name = shift;
  my %hash_id_color;
  my $color = 1;

  open( BLAST_FILE, "$blast_file_name") or die "Couldn't open $blast_file_name $! \n";
  while(my $line = <BLAST_FILE>)
  {
    chomp $line;
    my @line_fields = split(/\t/,$line);
    my $org1 = $line_fields[0];
    my $org2 = $line_fields[1];
    my $job_gen_org1 = "";
    my $job_gen_org2 = "";

    $org1 =~ /peg\.(\d+\|\d+)_/;
    $job_gen_org1 = $1;

    $org2 =~ /peg\.(\d+\|\d+)_/;
    $job_gen_org2 = $1;

      #new equivalence class
      if(! exists $hash_id_color{$job_gen_org1} && ! exists $hash_id_color{$job_gen_org2})
      {
        #print "$job_gen_org1 \t $job_gen_org2\n";
        $hash_id_color{$job_gen_org1} = [$color,$org1];
        $hash_id_color{$job_gen_org2} = [$color,$org2];
        $color++;
        #print keys %hash_id_color;
      }
      elsif(! exists $hash_id_color{$job_gen_org1}) #class org2 exists, make org1 the same class as org2
      {
        $hash_id_color{$job_gen_org1} = [$hash_id_color{$job_gen_org2}[0],$org1];
      }
      elsif(! exists $hash_id_color{$job_gen_org2}) #class org1 exists, make org2 the same class as org1
      {
        $hash_id_color{$job_gen_org2} = [$hash_id_color{$job_gen_org1}[0],$org2];
      }
    }
    close BLAST_FILE;
    #foreach( keys %hash_id_color )
    #{
    #  print $hash_id_color{$_}[1], "\t", $hash_id_color{$_}[0],"\n";
    #}
  return \%hash_id_color;
}



sub printClusters{
  my $out_name = shift;
  my $ref_hash_id_color = shift;

  open OUT_FILE, ">", "$out_name/clusters.cl" or die "Couldn't create $out_name/clusters.cl $! \n";
  foreach( sort keys %$ref_hash_id_color )
  {
    #add function to output clusters
    my $org_name = $ref_hash_id_color->{$_}[1];
    $org_name =~ /\|(\d+\_\d+)/;
    my $job_gen = $1;
    my $search = $`;
    my $Grep=`grep '$search' $out_name/$job_gen.input`;
    my @sp = split(/\t|\n/,$Grep);
    my $func = $sp[5];
    print OUT_FILE  $org_name, "\t" , $ref_hash_id_color->{$_}[0], "\t", $func, "\n";
  }
  close OUT_FILE;
}

sub readColorsCluster{

  my $input_file_name = shift;
  my %hash_color;
  my $org;
  my $job_id_hit;
  my @columns;
  open (COLORS_FILE, "$input_file_name") or die "Couldn't open $input_file_name $! \n";

  while(my $line = <COLORS_FILE>)
  {
    chomp $line;
    @columns = split("\t",$line);
    $columns[0] =~ /\|(\d+_\d+)/;
    $org = $`;  # get the original organism name i.e everything before \#####_###
    $job_id_hit = $1;
    $hash_color{$job_id_hit}{$org} = $columns[1];
  }
  close COLORS_FILE;
  return \%hash_color;
}

sub makeClusterFunction{

  my $input_file_name = shift;
  my $special_org = shift;
  my $org_number;
  my $color;
  my $function;
  my $counter = 0;
  my $marker = "special_org";
  my @columns;
  my %hash_color_funtions;
  my %hash_color_special_org;

  print "**********SPECIAL ORG: $special_org \n";

  open (COLORS_FILE, "$input_file_name") or die "Couldn't open $input_file_name $! \n";
  while(my $line = <COLORS_FILE>)
  {
    $counter+=1;
    chomp $line;
    @columns = split("\t",$line);
    $columns[0] =~ /\|(\d+)_\d+/;
    $org_number = $1;
    $color = $columns[1];
    $function = $columns[2];

      if(! exists $hash_color_funtions{$color} or !exists $hash_color_funtions{$color}{$function})
      {
          $hash_color_funtions{$color}{$function} = 1;
      }
      else
      {
        $hash_color_funtions{$color}{$function} += 1;
      }

      if($org_number == $special_org)
      {
          #mark if the special_org is part of this class ($color) and asign the function of the spercial org
          $hash_color_funtions{$color}{$marker} = $function;
      }
  }
  close COLORS_FILE;

  #WRITE REPORT FILE
  #color \t recurrenceColor \t function1,recurrenceFuncion1, function2, recurrenceFunction2, ....
  open OUT_FILE, ">", "$out_name/report_clusters.cl" or die "Couldn't create $out_name/report_clusters.cl $! \n";
  #open OUT_FILE, ">", "report_clusters.cl" or die "Couldn't create report_clusters.cl $! \n";

  foreach my $col (sort keys %hash_color_funtions) {
      my $temp_count = 0; # color recurrence
      foreach my $func (keys %{ $hash_color_funtions{$col} }) {
          if($func ne $marker)
          {
            $temp_count += $hash_color_funtions{$col}{$func};
          }
      }
      my $temp_percentaje = ($temp_count*100.0)/$counter;
      print OUT_FILE  $col, "\t",$temp_count, "\t" , $temp_percentaje, "\t";
      if(exists $hash_color_funtions{$col}{$marker})
      {
        my $temp_func = $hash_color_funtions{$col}{$marker};
        print OUT_FILE " * $temp_func \t $hash_color_funtions{$col}{$temp_func} \t ";
        delete($hash_color_funtions{$col}{$marker});
        delete($hash_color_funtions{$col}{$temp_func});
      }

      foreach my $func (reverse sort { $hash_color_funtions{$col}{$a} <=> $hash_color_funtions{$col}{$b} } keys %{$hash_color_funtions{$col}}) {
          print OUT_FILE "$func \t $hash_color_funtions{$col}{$func} \t ";
      }
      print OUT_FILE "\n";
  }
  close OUT_FILE;
}
