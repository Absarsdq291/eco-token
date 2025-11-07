const fs = require("fs");
const path = require("path");

const logNewLine = () => {
    // Logging new line.
    console.log();
};

const overwriteLog = (message) => {
    // Overwriting output to terminal using a prepended carriage return and clearing from cursor to end of line.
    process.stdout.write(`\r\x1b[K${message}`);
};

const separateInitialLogs = () => {
    // Getting start time.
    const startTime = Date.now();

    // Getting buffer time.
    const bufferTime = 3000;

    // Getting artifacts path.
    const artifactsPath = path.join(process.cwd(), "artifacts", "contracts");

    // Recursively traversing artifacts to retrieve the latest artifacts modification time.
    let latestArtifactsModificationTime = 0;

    const scrapLatestModificationTime = (artifactsPath) => {
        const entries = fs.readdirSync(artifactsPath, { withFileTypes: true });

        for (const entry of entries) {
            const entryPath = path.join(artifactsPath, entry.name);

            if (entry.isDirectory()) {
                scrapLatestModificationTime(entryPath);
            } else if (entry.name.endsWith(".json")) {
                const latestModificationTime = fs.statSync(entryPath).mtimeMs;

                latestArtifactsModificationTime = Math.max(latestArtifactsModificationTime, latestModificationTime);
            }
        }
    };

    scrapLatestModificationTime(artifactsPath);

    if (latestArtifactsModificationTime > startTime - bufferTime) {
        // Separating logs.
        logNewLine();
    }
};

const wait = async (waitTimeExpression, quiet) => {
    if (!quiet) {
        // Forwarding without silencing logs.
        await waitWithLogs(waitTimeExpression);

        return;
    }

    // Saving console method.
    const log = console.log;

    // Overriding console method with no-op.
    console.log = () => {};

    try {
        // Forwarding with silenced logs.
        await waitWithLogs(waitTimeExpression);

        return;
    } finally {
        // Restoring console method.
        console.log = log;
    }
};

const waitWithLogs = async (waitTimeExpression) => {
    // Parsing wait time expression into its time and corresponding unit.
    const [time, unit] = waitTimeExpression.split(" ");

    // Determining wait time in milliseconds and proper wait unit.
    let waitTime;
    let properWaitUnit;

    switch (unit) {
        case "m":
        case "minute":
        case "minutes":
            waitTime = time * 60 * 1000;
            properWaitUnit = time === "1" ? "minute" : "minutes";

            break;
        case "s":
        case "second":
        case "seconds":
            waitTime = time * 1000;
            properWaitUnit = time === "1" ? "second" : "seconds";

            break;
        case "ms":
        case "millisecond":
        case "milliseconds":
        default:
            waitTime = Number(time);
            properWaitUnit = time === "1" ? "millisecond" : "milliseconds";

            break;
    }

    // Separating logs.
    logNewLine();

    // Logging wait time.
    console.log("Waiting", time, properWaitUnit);

    // Waiting.
    await new Promise((resolve) => setTimeout(resolve, waitTime));
};

module.exports = {
    separateInitialLogs,
    logNewLine,
    overwriteLog,
    wait
};
