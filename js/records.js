/*
 * The 10 fastest official 3x3x3 single world records (the last 10 steps of
 * the WCA world-record progression), fastest first.
 *
 * Fill-in fields (all optional):
 *   youtube        – a YouTube video id or URL for the solve. Players can also
 *                    paste one in-game; that is saved in their browser.
 *   scramble       – the official WCA scramble for the solve.
 *   reconstruction – the solver's actual moves (rotations allowed: x y z,
 *                    wide moves r u f / Rw, slices M E S). Inspection
 *                    rotations go at the start.
 *
 * When `scramble` + `reconstruction` are both present, the REPLAY step shows
 * the real solve. Otherwise the game generates a scramble and shows a
 * computer-found solution, played back at the record's speed, and labels it
 * as such.
 */
window.RECORDS = [
  {
    time: 2.51,
    name: "Xuanyi Geng",
    country: "China",
    flag: "🇨🇳",
    competition: "Guangzhou Grand Open 2026",
    date: "2026",
    note: "Current world record. Shaved 0.25 s off the record.",
  },
  {
    time: 2.76,
    name: "Teodor Zajder",
    country: "Poland",
    flag: "🇵🇱",
    competition: "GLS Big Cubes 2026 (Gdańsk)",
    date: "Feb 2026",
    note: "First official sub-3 second solve, by a 9-year-old.",
  },
  {
    time: 3.05,
    name: "Xuanyi Geng",
    country: "China",
    flag: "🇨🇳",
    competition: "Shenyang Spring 2025",
    date: "Apr 13, 2025",
    note: "Beat Yiheng Wang's 3.08 from earlier that year.",
  },
  {
    time: 3.08,
    name: "Yiheng Wang",
    country: "China",
    flag: "🇨🇳",
    competition: "XMUM Cube Open 2025 (Malaysia)",
    date: "2025",
    note: "Ended Max Park's reign of nearly two years.",
    youtube: "C-GeHySM-Ko",
  },
  {
    time: 3.13,
    name: "Max Park",
    country: "USA",
    flag: "🇺🇸",
    competition: "Pride in Long Beach 2023",
    date: "Jun 11, 2023",
    note: "Broke a record that had stood for 4½ years.",
  },
  {
    time: 3.47,
    name: "Yusheng Du",
    country: "China",
    flag: "🇨🇳",
    competition: "Wuhu Open 2018",
    date: "Nov 24, 2018",
    note: "First sub-4. Only caught on the venue's security camera.",
  },
  {
    time: 4.22,
    name: "Feliks Zemdegs",
    country: "Australia",
    flag: "🇦🇺",
    competition: "Cube for Cambodia 2018",
    date: "May 6, 2018",
    note: "A 38-move solve from the most famous cuber ever.",
  },
  {
    time: 4.59,
    name: "SeungBeom Cho",
    country: "South Korea",
    flag: "🇰🇷",
    competition: "ChicaGhosts 2017",
    date: "Oct 2017",
    note: "Stood until Feliks' 4.22 in May 2018.",
  },
  {
    time: 4.69,
    name: "Patrick Ponce",
    country: "USA",
    flag: "🇺🇸",
    competition: "Rally In The Valley 2017",
    date: "Sep 2017",
    note: "Took the record from Feliks by 0.04 s.",
  },
  {
    time: 4.73,
    name: "Feliks Zemdegs",
    country: "Australia",
    flag: "🇦🇺",
    competition: "POPS Open 2016",
    date: "Dec 2016",
    note: "Feliks takes the record back from Mats Valk's 4.74 by 0.01 s.",
  },
];
