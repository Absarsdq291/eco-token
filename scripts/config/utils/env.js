const fs = require("fs");

const { ENV_STATE } = require("../common/states");

const updateEnv = (...args) => {
    let variables = {};
    let filePathIndex;

    // Parsing arguments.
    const [firstArgument] = args;

    if (typeof firstArgument === "string") {
        // Processing for a key-value pair, if the first parameter is a string.
        variables[firstArgument] = args[1];
        filePathIndex = 2;
    } else if (firstArgument && typeof firstArgument === "object") {
        // Using directly, if the first parameter is an object.
        variables = firstArgument;
        filePathIndex = 1;
    } else {
        throw new Error("Error: invalid arguments");
    }

    const filePath = args[filePathIndex] || ".env";

    // Loading env.
    if (!ENV_STATE[filePath]) {
        // Getting content.
        const content = fs.readFileSync(filePath, "utf8");

        // Saving content to shared state.
        ENV_STATE[filePath] = content;
    }

    // Parsing env.
    const lines = ENV_STATE[filePath].split("\n");
    const keys = Object.keys(variables);
    const allKeys = new Set();

    // Updating environment variables where applicable.
    content = "";

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmedLine = line.trim();

        if (trimmedLine && !trimmedLine.startsWith("#") && trimmedLine.includes("=")) {
            const [currentKey] = trimmedLine.split("=");

            if (keys.includes(currentKey)) {
                content += `${currentKey}=${variables[currentKey]}`;

                allKeys.add(currentKey);
            } else {
                content += line;
            }
        } else {
            content += line;
        }

        if (i < lines.length - 1) {
            content += "\n";
        }
    }

    // Adding trailing blank line.
    if (!content.endsWith("\n")) {
        content += "\n";
    }

    // Adding new environment variables where applicable.
    keys.forEach((key) => {
        if (!allKeys.has(key)) {
            content += "\n";
            content += `${key}=${variables[key]}`;

            if (key === keys[keys.length - 1]) {
                content += "\n";
            }
        }
    });

    // Saving env to shared state.
    ENV_STATE[filePath] = content;

    // Saving env to file.
    fs.writeFileSync(filePath, content);
};

module.exports = {
    updateEnv
};
