#!/bin/bash
# url-compare
# USAGE: ./url-compare.sh <rules.txt 2>error_log
#
# script in support of 'privoxy'
#
# accepts as input a list in form
#     URL1 URL2 unique_ouput_filename
# downloads the urls in text only format and compares them
# the urls, diffs and error_logs are stored in four separate folders
# a short summary is printed
# zero-length files are deleted to ease archiving

# NOTES
#
# DEPRECATED: This awk statement was required in order to convert
# D's original input list into a format I could use
# awk '{gsub(" ","_"); gsub("_http"," http"); http=$2; gsub("/","",$2); gsub("/","",$1); printf "%s %s %05d__%s__%s\n", http, $3, NR, $1, $2}' <rules.txt >rules_v2.txt



# TECHNIQUE COMPARISON
# I had originally wanted to perform this script's function using GNUparallel
# but had made syntax mistakes, so did my initial run without it. When I
# did find my syntax error and ran a test, GNUparallel ran twice as fast
# ... on my dual-core laptop.
# parallel --colsep ' ' "diff <(lynx --dump -nolist {1} | tee ${DIR1}/{3}) <(lynx --dump -nolist {2} | tee ${DIR2}/{3}) >${DIR3}/{3}" <test_data_2
# took 21 seconds for the 11 line input file "test_data"
# while read URL1 URL2 OUTFILE; do
#   diff <(lynx --dump -nolist ${URL1} | tee ${DIR1}/${OUTFILE}) <(lynx --dump -nolist ${URL2} | tee ${DIR2}/${OUTFILE}) >${DIR3}/${OUTFILE}
#   done
# took 45 seconds for the 11 line input file "test_data"
#
# Also, in retrospect, this doesn't seem like proper use of parallel, because
# we primarily benefit from the downloading being done either multithreaded
# or in parallel, and the above statement is performing the diff in parallel
# and, since my hardware is just dual-core, two of the above diff statements
# won't be running their input sub-processes to lynx in parallel (no more
# cores available). Truth is, even if I had quad-core, the parallelism would
# be grabbed by the diff statement.
#
# An alternative speed boost would be:
#    xargs wget (can accept many URLs, but not dump text only)
# and then find an alternative to lynx for stripping html
# that could be used in a secodnd xargs statement
# vs
#    lynx (can accept only one url per launch, but can text dump)


DIR1=1_http_files
DIR2=2_https_files
DIR3=3_diff_results
DIR4=4_error_logs
REPORT_FILE=summary_report

printf "" > num_input > ${REPORT_FILE}

for TEST_DIR in $DIR1 $DIR2 $DIR3 $DIR4;
do
   if [ -e ${TEST_DIR} ] ;
   then
      printf "error, ${TEST_DIR} already exists. exiting.\n"
      exit
   else
      mkdir ${TEST_DIR}
   fi
done


# Some lynx options to play with
# -read-timeout=10
# -timeout=N   For win32, sets the network read-timeout, where N is given in seconds.no diff for images
# -stderr     When  dumping a document using -dump or -source, Lynx normally does not display alert (error) messages that you see on the screen in
#             the status line.  Use the -stderr option to tell Lynx to write these messages to the standard error.
# -traversal  traverse  all  http links derived from startfile.  When used with -crawl, each link that begins with the same string as startfile is
#             output to a file, intended for indexing.  See CRAWL.announce for more information.
# -crawl with -traversal, output each page to a file.  with -dump, format output as with -traversal, but to the standard output.
# -error_file=FILE define a file where Lynx will report HTTP access codes.
#
# Some parallel options to play with
# --halt <0|1|2> 0  Do not halt if a job fails. Exit status will be the number of jobs failed. This is the default.
# --progress     Show progress of computations.
# --resume       Resumes from the last unfinished job. By reading --joblog GNU parallel will figure out the last
#                unfinished job and continue from there. requires --joblog
# --bg           Run command in background
# --jobs
# --joblog


LYNX_OPTS="-dump -nolist -connect_timeout=10 -stderr"
# PAR_OPTS=" --jobs 0"
PAR_OPTS="--progress --jobs 20"


parallel --colsep ' ' ${PAR_OPTS} \
   "\
    printf "1" >> num_input; \
    diff -bBE <(lynx ${LYNX_OPTS} {1} 2>${DIR4}/{3}_1 | tee ${DIR1}/{3}) <(lynx ${LYNX_OPTS} {2} 2>${DIR4}/{3}_2 | tee ${DIR2}/{3}) >${DIR3}/{3} 2>>diff_error_log"

NUM_INPUT=$( wc -m <num_input )
NUM_MATCHED=$( find ${DIR3} -mindepth 1 -type f -empty -print -delete | wc -l)
HTTP_FAILED=$( find ${DIR4} -mindepth 1 -name '*_1' \( ! -empty -print -o -delete \) | wc -l)
HTTPS_FAILED=$(find ${DIR4} -mindepth 1 -name '*_2' \( ! -empty -print -o -delete \) | wc -l)
DIFF_FAILED=$( find ${DIR3} -mindepth 1 -type f ! -empty | wc -l)

find ${DIR1} ${DIR2} ${DIR3} -empty -delete

printf "\nTest complete - %d URL pairs were checked:\n\
  %5d identical url pairs\n\
  %5d failed on diff check\n\
  %5d failed on https request\n\
  %5d failed on http request\n\n"\
    ${NUM_INPUT} ${NUM_MATCHED} $(( ${DIFF_FAILED}-${HTTP_FAILED}-${HTTPS_FAILED} )) ${HTTPS_FAILED} ${HTTP_FAILED} | tee ${REPORT_FILE}

grep --no-filename -e ^HTTP -e ^Alert ${DIR4}/* | sort | uniq -cdi | tee -a ${REPORT_FILE}
grep --no-filename -e ^Can\'t ${DIR4}/* | sed "s/:.*//" | sort | uniq -cdi | tee -a ${REPORT_FILE}
grep --no-filename -e ^lynx ${DIR4}/* | sed "s/:\/.*//" | sort | uniq -cdi | tee -a ${REPORT_FILE}
grep --no-filename -e ^Unable ${DIR4}/* | sed 's/[^ ]*$//' | sort | uniq -cdi | tee -a ${REPORT_FILE}


rm num_input

exit
