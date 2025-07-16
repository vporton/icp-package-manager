import { exec } from "child_process";

export function commandOutput(command: string): Promise<string> {
    return new Promise((resolve, reject) =>
        exec(command, (error, stdout, stderr) => {
            if (error) {
                reject(error);
                return;
            }
            if (stderr) {
                // Preserve the previous behaviour of returning stdout even if
                // there are warnings, but surface them to the caller.
                console.warn(stderr);
            }
            resolve(stdout);
        })
    );
}
