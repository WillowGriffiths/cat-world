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
      if (last_line.length + word.length + 1 > length) {
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

async function say(speaker, message) {
  const billy = await getArt(speaker);

  let lines = wrap(message, 32);

  const insert = lines.reduce((insert, text) => {
    const whitespace = " ".repeat(32 - text.length);
    return insert + `         |  ${text + whitespace}  |\n`;
  }, "");

  const output = billy.replace("{lines}", insert);

  process.stdout.write(output);
}

async function billySay(message) {
  await say("billy", message);
}

async function henrySay(message) {
  await say("henry", message);
}

async function gamblingSay(message) {
  await say("gambling_speech", message);
}

async function spinningCat(_state, _visited) {
  await billySay(
    "The spinning cat is an excellent choice. With the engaging visuals and evocative subject matter, it really is fun for all the family! Enter here for 5 seconds of cat spinning action\n\nPress ENTER to start",
  );

  prompt("");

  await Bun.sleep(500);

  showCat();
}

async function letsGoGambling(state, visited) {
  process.stdout.write(await getArt("gambling"));
  if (!visited) {
    await billySay(
      "Gambling is an excellent way to spend your time at Cat World! We've developed a way to gamble without your money, making this game perfectly safe for all the family to enjoy.\n\nPress ENTER to continue",
    );

    prompt("");
  }

  await gamblingSay("Heyyy kid, why not gamble a bit???");

  let exit = false;
  while (!exit) {
    let valid = false;
    let rolls;
    while (!valid) {
      const entry = prompt("Rolls (ENTER to leave):");
      if (entry === null) {
        exit = true;
        break;
      }

      rolls = parseInt(entry);
      if (rolls < 1) {
        await gamblingSay(
          "Come on kid, you've got to try at least once! Be warned though, it'll cost - uhh... nothing! Absolutely nothing :)",
        );
      } else if (rolls > 10) {
        await gamblingSay("Woah kid, that's far too many! Calm down a bit.");
      } else {
        valid = true;
      }
    }

    if (!valid) {
      await gamblingSay(
        "Sorry to see ya go, kid. Don't spend it all at once.\n\nPress ENTER to continue",
      );
      prompt("");
    } else {
      for (let i = 0; i < 3; i++) {
        process.stdout.write(".");
        await Bun.sleep(200);
      }

      process.stdout.write("\n");

      let results = [];
      for (let i = 0; i < rolls; i++) {
        let result = [];
        for (let i = 0; i < 3; i++) {
          const num = Math.floor(Math.random() * 3);
          const chars = ["x", ":", "3"];
          result.push(chars[num]);
        }
        results.push(result);
      }

      const wins = results.filter(
        (result) => result[0] === result[1] && result[1] === result[2],
      ).length;

      const reward = wins * 5;
      state.dollarydoos += reward;

      for (let result of results) {
        process.stdout.write(
          (await getArt("gambling_result"))
            .replace("{1}", result[0])
            .replace("{2}", result[1])
            .replace("{3}", result[2]),
        );
        await Bun.sleep(200);
      }

      if (wins > 0) {
        const s = wins > 1 ? "s" : "";
        await gamblingSay(
          `Hey kid, ${wins} win${s}! That earns you $${reward} to spend at Cat World. Wanna go again?`,
        );
      } else {
        await gamblingSay("Sorry kid, nothing this time. Wanna go again?");
      }
    }
  }
}

async function merchShop(state, visited) {
  await process.stdout.write(await getArt("merch"));

  if (!visited) {
    await billySay(
      "Welcome to the merch shop! Here, you can buy all kinds of things with your hard earned dollarydoos. It truly is fun for all the family! If anything catches your interest, talk to our shopkeeper Henry here.\n\nPress ENTER to continue",
    );

    prompt("");

    await henrySay(
      "That's right, boss! My shop has everything you could want!\n\nPress ENTER to continue",
    );

    prompt("");
  }

  while (true) {
    let stock = state.shop.filter((item) => !item.bought);

    const message = stock
      .entries()
      .reduce(
        (accum, [index, element]) =>
          accum + `\n ${index + 1}) ${element.name}: $${element.price}`,
        "Welcome to my shop! Tell me if you see something you like. We stock: ",
      );

    await henrySay(message);

    let valid = false;
    let choice;
    while (!valid) {
      const entry = prompt("Choice (ENTER to leave): ");
      if (entry == null) {
        break;
      }

      choice = parseInt(entry);
      valid = choice > 0 && choice <= stock.length;
    }

    if (valid) {
      let item = stock[choice - 1];

      process.stdout.write(await getArt(item.art_name));
      await henrySay(item.description + ` Wanna buy it for $${item.price}?`);

      if (confirm("")) {
        if (state.dollarydoos >= item.price) {
          item.bought = true;
          state.dollarydoos -= item.price;
          await henrySay(
            `Great! $${item.price} please.\n\nPress ENTER to continue`,
          );
        } else {
          await henrySay(
            "Gr- uh... you can't afford it? Maybe try gambling a bit and come back.\n\nPress ENTER to continue",
          );
        }

        prompt("");
      } else {
        await henrySay(
          "That's a shame. Let me know if you change your mind!\n\nPress ENTER to co ntinue",
        );
        prompt("");
      }
    } else {
      await henrySay("Bye! Come again!\n\nPress ENTER to continue");
      prompt("");
      break;
    }
  }
}

async function main() {
  process.stdout.write(await getArt("cat-world"));

  await billySay(
    "Welcome to Cat World! I'm Billy, the titular cat. Here, you'll find a ton of fun activites. Spend your dollarydoos to partake in them. It's fun for the entire family! Here's $5 to start.\nPress ENTER to start",
  );
  prompt("");

  let activities = [
    {
      price: 2,
      name: "[WIP] Spinning Cat",
      callback: spinningCat,
      visited: false,
    },
    {
      price: 0,
      name: "Gambling",
      callback: letsGoGambling,
      visited: false,
    },
    {
      price: 0,
      name: "Merch Shop",
      callback: merchShop,
      visited: false,
    },
  ];

  let state = {
    dollarydoos: 5,
    visited_merch: false,

    shop: [
      {
        price: 20,
        name: "Collar",
        art_name: "collar",
        bought: false,
        description:
          "The collar is an excellent choice! It's stylish and comfortable.",
      },
      {
        price: 10,
        name: "Hairbrush",
        art_name: "brush",
        bought: false,
        description:
          "The hairbrush is a great and affordable way to comb your fur",
      },
    ],
  };

  while (true) {
    let index = 1;
    const message = activities.reduce((prev, activity) => {
      const price_label = activity.price > 0 ? `$${activity.price}` : "Free";

      const output = prev + `\n ${index}) ${activity.name}: ${price_label}`;
      index += 1;
      return output;
    }, `You have ${state.dollarydoos} dollarydoos.\n\nThe available fun-for-all-the-family activities are as follows:`);
    await billySay(message);

    let response;
    let valid = false;
    while (!valid) {
      response = parseInt(prompt(`Pick an activity <1-${activities.length}>:`));
      valid = response > 0 && response <= activities.length;
    }

    const activity = activities[response - 1];
    if (activity.price > state.dollarydoos) {
      await billySay("Woah buddy, that's too expensive for you!");
    } else {
      state.dollarydoos -= activity.price;
      process.stdout.write(` -$${activity.price}\n`);
      await activity.callback(state, activity.visited);
      activity.visited = true;
    }
  }
}

await main();
