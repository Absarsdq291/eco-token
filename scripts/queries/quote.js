const hardhat = require("hardhat");

const DECIMALS_DEFAULT = 18;
const Q96 = 96n;

const quote = () => {
    // Quote variables.
    const amount0 = process.env.AMOUNT0_QUOTE;
    const amount1 = process.env.AMOUNT1_QUOTE;
    let decimals0 = process.env.DECIMALS0_QUOTE;
    let decimals1 = process.env.DECIMALS1_QUOTE;

    // Structuring quote variables.
    decimals0 = Number(decimals0) || DECIMALS_DEFAULT;
    decimals1 = Number(decimals1) || DECIMALS_DEFAULT;

    // Converting data.
    let convertedAmount0 = hardhat.ethers.parseUnits(amount0, decimals0);
    let convertedAmount1 = hardhat.ethers.parseUnits(amount1, decimals1);

    // Calculate sqrtPriceX96.
    const sqrtPriceX96 = calculateSqrtPriceX96(convertedAmount0, convertedAmount1);

    // Calculate inverted sqrtPriceX96.
    const invertedSqrtPriceX96 = calculateSqrtPriceX96(convertedAmount1, convertedAmount0);

    // Setting up log variables.
    const formattedAmount0 = formatInteger(amount0);
    const formattedAmount1 = formatInteger(amount1);
    convertedAmount0 = convertedAmount0.toString();
    convertedAmount1 = convertedAmount1.toString();

    // Logging data.
    console.log("Amount0                :", formattedAmount0, `(${decimals0} decimals)`);
    console.log("Amount1                :", formattedAmount1, `(${decimals1} decimals)`);
    console.log("Amount0 in wei         :", convertedAmount0, `(${decimals0} decimals)`);
    console.log("Amount1 in wei         :", convertedAmount1, `(${decimals1} decimals)`);
    console.log("SqrtPriceX96           :", sqrtPriceX96);
    console.log("Inverted SqrtPriceX96  :", invertedSqrtPriceX96);

    process.exit();
};

// Calculates sqrtPriceX96 given the amounts of both tokens.
const calculateSqrtPriceX96 = (amount0, amount1) => {
    // Multiplying first to avoid floating point errors.
    const numerator = amount1 * 2n ** (Q96 * 2n);
    const priceX192 = numerator / amount0;

    // Calculate square root.
    const sqrtPriceX96 = sqrtBigInt(priceX192);

    return sqrtPriceX96.toString();
};

// Calculates sqrt of a bigint using Newton's method.
const sqrtBigInt = (value) => {
    if (value === 0n) return 0n;
    if (value < 4n) return 1n;

    let currentGuess = value;
    let nextGuess = (value + 1n) / 2n;

    while (nextGuess < currentGuess) {
        currentGuess = nextGuess;
        nextGuess = (currentGuess + value / currentGuess) / 2n;
    }

    return currentGuess;
};

// Formats integer to human readable form.
const formatInteger = (integer) => {
    // Converting integer to string and removing any existing commas/spaces.
    let stringifiedInteger = integer.toString().replace(/[\s,]/g, "");

    // Removing any decimal part if present.
    stringifiedInteger = stringifiedInteger.split(".")[0];

    // Adding commas every 3 digits from the right.
    const formattedInteger = stringifiedInteger.replace(/\B(?=(\d{3})+(?!\d))/g, ",");

    return formattedInteger;
};

quote().catch((error) => {
    // Logging error.
    console.error(error);

    // Exiting with failure.
    process.exitCode = 1;
    process.exit();
});
