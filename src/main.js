import { dlopen, FFIType, suffix } from "bun:ffi";

const path = `./zig-out/lib/libcat.${suffix}`;

const {
  symbols: { showCat },
} = dlopen(path, {
  showCat: {
    args: [],
    returns: FFIType.void,
  },
});

async function getArt(name) {
    const path = `src/art/${name}.txt`;
    const file = Bun.file(path);

    const text = await file.text();
    return text;
}

function wrap(message, length) {
    const paragraphs = message.split("\n");
    let lines = [];

    for (let j = 0; j < paragraphs.length; j++) {
        const words = paragraphs[j].split(" ");
        let last_line = words[0];
        for (let i = 1; i < words.length; i++) {
            const word = words[i];
            if (last_line.length + word.length + 1> length) {
                lines.push(last_line);
                last_line = word;
            } else {
                last_line += " " + word;
            }
        }
        lines.push(last_line);
    }


    return lines;
}

async function say(message) {
    const billy = await getArt("billy");

    let lines = wrap(message, 32);

    const insert = lines.reduce(
        (insert, text) => {
            const whitespace = ' '.repeat(32 - text.length);
            return insert + `         |  ${text + whitespace}  |\n`;
        },
        ""
    );

    const output = billy.replace("{lines}", insert);

    process.stdout.write(output);
}

async function spinningCat() {
    await say("The spinning cat is an excellent choice. With the engaging visuals and evocative subject matter, it really is fun for all the family!\nPress ENTER to start (press any key to leave).");

    prompt("");

    showCat();
}

async function main() {
    process.stdout.write(await getArt("cat-world"));

    await say("Welcome to Cat World! I'm Billy, the titular cat. Here, you'll find a ton of fun activites. Spend your dollarydoos to partake in them. It's fun for the entire family! Here's $5 to start.\nPress ENTER to start");
    prompt("");

    let dollarydoos = 5;

    let activities = [
        {price: 2, name: "[WIP] Spinning Cat", callback: spinningCat},
    ];

    while (true) {
        let index = 1;
        const message = activities.reduce(
            (prev, activity) => {
                const output = prev + `\n ${index}) ${activity.name}: $${activity.price}`;
                index += 1;
                return output;
            },
            `You have ${dollarydoos} dollarydoos.\n\nThe available fun-for-all-the-family activities are as follows:`
        );
        await say(message);
        
        let response;
        let valid = false;
        while (!valid) {
            response = parseInt(prompt(`Pick an activity <1-${activities.length}>:`));
            valid = response > 0 && response <= activities.length;
        }

        activities[response - 1].callback();
    }
}

await main();
