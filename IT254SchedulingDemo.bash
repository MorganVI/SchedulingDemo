cd ~/it254-scheduling
cat > fcfs-vs-rr.slurm <<'EOF'
#!/bin/bash
#SBATCH --job-name=it254-fcfs-vs-rr
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=256M
#SBATCH --time=00:02:00
#SBATCH --output=fcfs-vs-rr-%j.out

echo "Job ID: $SLURM_JOB_ID"
echo "Compute node: $(hostname)"
echo "Started: $(date)"

# --- Workload --------------------------------------------------------
# Four processes, all arriving at t=0. P1 is a long "hog" that
# creates the classic FCFS convoy effect; P2-P4 are short jobs
# stuck behind it.
pids=(P1 P2 P3 P4)
bursts=(10 2 2 2)
n=${#pids[@]}
quantum=2

echo
echo "Workload (all arrive at t=0):"
printf "  %-4s %6s\n" "PID" "Burst"
for i in "${!pids[@]}"; do
    printf "  %-4s %6d\n" "${pids[$i]}" "${bursts[$i]}"
done

# --- FCFS ------------------------------------------------------------
# Each process runs to completion in arrival order.
echo
echo "=== FCFS ==="
time=0
total_wait=0; total_turn=0; total_resp=0
gantt=""
printf "  %-4s %6s %6s %6s %6s %6s\n" "PID" "Burst" "Start" "Finish" "Wait" "Turn"
for i in "${!pids[@]}"; do
    start=$time
    finish=$((time + bursts[$i]))
    wait=$start            # arrival is 0 for everyone
    turn=$finish
    printf "  %-4s %6d %6d %6d %6d %6d\n" \
        "${pids[$i]}" "${bursts[$i]}" "$start" "$finish" "$wait" "$turn"
    gantt+="[${pids[$i]}:$start-$finish]"
    time=$finish
    (( total_wait += wait ))
    (( total_turn += turn ))
    (( total_resp += start ))
done
echo "  Gantt: $gantt"
fcfs_wait=$total_wait; fcfs_turn=$total_turn; fcfs_resp=$total_resp

# --- Round Robin -----------------------------------------------------
# Each process gets at most $quantum time units, then goes to the
# back of the ready queue if it still has work to do.
echo
echo "=== Round Robin (quantum=$quantum) ==="
remaining=("${bursts[@]}")
finish_time=(); first_run=()
for i in "${!pids[@]}"; do
    finish_time[$i]=0
    first_run[$i]=-1
done

queue=()
for i in "${!pids[@]}"; do queue+=("$i"); done

time=0; done_count=0; gantt=""
while (( done_count < n )); do
    idx=${queue[0]}
    queue=("${queue[@]:1}")
    if (( first_run[idx] < 0 )); then first_run[$idx]=$time; fi
    run=$(( quantum < remaining[idx] ? quantum : remaining[idx] ))
    gantt+="[${pids[$idx]}:$time-$((time + run))]"
    (( time += run ))
    (( remaining[idx] -= run ))
    if (( remaining[idx] == 0 )); then
        finish_time[$idx]=$time
        (( done_count += 1 ))
    else
        queue+=("$idx")
    fi
done

total_wait=0; total_turn=0; total_resp=0
printf "  %-4s %6s %6s %6s %6s %6s\n" "PID" "Burst" "Start" "Finish" "Wait" "Turn"
for i in "${!pids[@]}"; do
    start=${first_run[$i]}
    finish=${finish_time[$i]}
    turn=$finish            # arrival is 0
    wait=$((turn - bursts[$i]))
    printf "  %-4s %6d %6d %6d %6d %6d\n" \
        "${pids[$i]}" "${bursts[$i]}" "$start" "$finish" "$wait" "$turn"
    (( total_wait += wait ))
    (( total_turn += turn ))
    (( total_resp += start ))
done
echo "  Gantt: $gantt"
rr_wait=$total_wait; rr_turn=$total_turn; rr_resp=$total_resp

# --- Side-by-side comparison ----------------------------------------
echo
echo "=== Comparison (averages over $n processes) ==="
awk -v fw=$fcfs_wait -v ft=$fcfs_turn -v fr=$fcfs_resp \
    -v rw=$rr_wait   -v rt=$rr_turn   -v rp=$rr_resp \
    -v n=$n 'BEGIN {
    printf "  %-16s %8s %8s %8s\n",     "Metric",         "FCFS", "RR", "RR-FCFS"
    printf "  %-16s %8.2f %8.2f %+8.2f\n", "Avg waiting:",    fw/n, rw/n, rw/n - fw/n
    printf "  %-16s %8.2f %8.2f %+8.2f\n", "Avg turnaround:", ft/n, rt/n, rt/n - ft/n
    printf "  %-16s %8.2f %8.2f %+8.2f\n", "Avg response:",   fr/n, rp/n, rp/n - fr/n
}'

echo
echo "Finished: $(date)"
EOF
sbatch fcfs-vs-rr.slurm   # record the job id

squeue -u "$USER"

cat [place your job id here].out
seff [place your job id here]