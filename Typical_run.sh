#split
$STRAW_DN/Denovo-assembly_pipeline/scripts/PIPELINE.sh -c splitfq \
  $STRAW_DN/../raw/D2_1.fq.gz \
  5000000 \
  $STRAW_DN/split

$STRAW_DN/Denovo-assembly_pipeline/scripts/PIPELINE.sh -c splitfq \
  $STRAW_DN/../raw/D2_2.fq.gz \
  5000000 \
  $STRAW_DN/split

#trim
for R1 in $STRAW_DN/split/D2_1.fq.gz.aaaa*; do
  R2=$(echo $R1|sed 's/_1/_2/');
  $STRAW_DN/Denovo-assembly_pipeline/scripts/PIPELINE.sh -c trim \
  $R1 \
  $R2 \
  $STRAW_DN/trimmed \
  $STRAW_DN/Denovo-assembly_pipeline/scripts/truseq.fa \
  4
done

#clean
for R1 in $STRAW_DN/trimmed/D2_1.fq.gz.aaaa*; do
  R2=$(echo $R1|sed 's/_1/_2/');
  $STRAW_DN/Denovo-assembly_pipeline/scripts/PIPELINE.sh -c clean \
  $R1 \
  $R2 \
  $STRAW_DN/cleaned \
  0.1 \
  0.25
done

#filter
for R1 in $STRAW_DN/cleaned/D2_1.fq.gz.aaaa*.f.*; do 
  R2=$(echo $R1|sed 's/\.f\./\.r\./'); 
  $STRAW_DN/Denovo-assembly_pipeline/scripts/PIPELINE.sh -c filter \
  $STRAW_DN/../contaminants/contaminants \
  $STRAW_DN/filtered \
  $R1 $R2
done

#normalise
