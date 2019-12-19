# Parse slurmd -C command to get the line to add in cluster.conf
import subprocess

output = subprocess.check_output(["slurmd","-C"])
tempout = []

# Remove Boards from slurmd
for aa in output.split()[:-1]:
    if not aa.startswith(b'Boards'):
        tempout.append(aa.decode("utf-8"))

# Get Memory and reduce it by 1024
finalout = []
for aa in tempout:
    if aa.startswith("RealMemory"):
        memory = int(aa.split("=")[1])
        if memory > 1024:
            finalout.append("RealMemory="+str(memory-1024))
        else:
            finalout.append(aa)
    else:
        finalout.append(aa)

print(' '.join(finalout))