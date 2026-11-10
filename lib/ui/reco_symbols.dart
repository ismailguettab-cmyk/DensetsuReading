// Generated from the Claude Design board "Reco" (silhouettes and symbols on the category books).
// Each part: (true = drawn in the book's ink colour, false = cut out in the book colour), SVG path, even-odd fill.

typedef BookPart = (bool, String, bool);

/// Three characters standing side by side (viewBox 200 × 150): shōnen, seinen, josei.
const bookTrios = <String, List<BookPart>>{
  "shounen": [(true, "M6 150c0-24 14-38 36-38s36 14 36 38z", false), (true, "M35 96h14v20H35z", false), (true, "M24 82a18 20 0 1 0 36 0a18 20 0 1 0-36 0z", false), (true, "M20 80l-10-8 12-2-10-14 14 4-4-16 14 10 4-16 8 14 10-12 2 16 14-8-6 14 14 0-12 10 8 6-16 2z", false), (false, "M24 69h36v8H24z", false), (true, "M34 70h16v6H34z", false), (false, "M26 116c8 8 24 8 32 0v4c-8 8-24 8-32 0z", false), (true, "M146 150l38-140 14 4-34 136z", false), (false, "M181 22l12 3-1 4-12-3z", false), (true, "M122 150c0-24 14-38 36-38s36 14 36 38z", false), (true, "M151 96h14v20h-14z", false), (true, "M140 82a18 20 0 1 0 36 0a18 20 0 1 0-36 0z", false), (true, "M136 82l-8-6 10-4-8-12 12 2-2-14 12 8 6-14 6 12 10-10 2 14 12-4-6 12 12 4-12 6 6 8-14-2z", false), (false, "M150 114l8 22 8-22h-4l-4 12-4-12z", false), (true, "M56 150c0-30 18-44 44-44s44 14 44 44z", false), (true, "M92 92h16v18H92z", false), (true, "M78 76a22 24 0 1 0 44 0a22 24 0 1 0-44 0z", false), (true, "M76 64c0-20 10-32 24-32s24 12 24 32z", false), (true, "M52 66c0-6 21-10 48-10s48 4 48 10-21 8-48 8-48-2-48-8z", false), (false, "M77 55h46v5H77z", false), (false, "M90 108l10 32 10-32h-4l-6 18-6-18z", false)],
  "seinen": [(true, "M124 150 192 60l4 3-66 90z", false), (true, "M196 150 130 62l-4 3 64 85z", false), (true, "M122 150c0-24 14-38 36-38s36 14 36 38z", false), (true, "M151 96h14v20h-14z", false), (true, "M140 82a18 20 0 1 0 36 0a18 20 0 1 0-36 0z", false), (true, "M138 84c-4-22 6-36 20-36s26 12 20 36l-4-10-4 8-4-12-4 10-6-12-4 10-4-10-4 12z", false), (false, "M146 114l12 12 12-12-3-1-9 8-9-8z", false), (false, "M140 128h36v3h-36z", false), (true, "M6 150c0-24 14-38 36-38s36 14 36 38z", false), (true, "M35 96h14v20H35z", false), (true, "M24 82a18 20 0 1 0 36 0a18 20 0 1 0-36 0z", false), (true, "M22 80c-2-20 6-32 20-32s24 10 20 32c-4-10-10-14-18-14-4 6-12 10-22 14z", false), (false, "M34 114l8 14 8-14z", false), (true, "M40 116h4l2 16-4 4-4-4z", false), (true, "M56 118l22-4 4 28-22 4z", false), (false, "M60 123l15-3 1 4-15 3z", false), (true, "M128 26h8v20h-8z", false), (true, "M116 44h32v7h-32z", false), (true, "M121 51h22v99h-22z", false), (true, "M50 150c2-30 20-46 50-46s48 16 50 46z", false), (true, "M92 92h16v16H92z", false), (true, "M78 76a22 24 0 1 0 44 0a22 24 0 1 0-44 0z", false), (true, "M76 74l-4-12 8 2-2-12 10 6 4-12 8 10 8-10 4 12 10-6-2 12 8-2-4 12-8-6-8 6-8-6-8 6-8-6z", false), (false, "M60 122c10-8 22-10 30-8l-2 4c-8-2-18 0-26 6z", false), (false, "M86 128h28v3H86z", false)],
  "josei": [(true, "M18 86c-6-24 6-40 24-40s30 16 24 40c4 8 2 20-4 26l-4-22c-2-10-6-14-16-14s-14 4-16 14l-4 22c-6-6-8-18-4-26z", false), (true, "M6 150c0-24 14-38 36-38s36 14 36 38z", false), (true, "M35 96h14v20H35z", false), (true, "M24 82a18 20 0 1 0 36 0a18 20 0 1 0-36 0z", false), (true, "M24 78c0-16 8-26 18-26s18 10 18 26c-6-8-12-10-18-10s-12 2-18 10z", false), (true, "M28 50l-10-8v16zM36 50l10-8v16z", false), (false, "M30 118h24v3H30z", false), (true, "M138 86c-2-22 6-36 20-36s22 14 20 36v50h-8V92h-24v44h-8z", false), (true, "M122 150c0-24 14-38 36-38s36 14 36 38z", false), (true, "M151 96h14v20h-14z", false), (true, "M140 82a18 20 0 1 0 36 0a18 20 0 1 0-36 0z", false), (true, "M140 78c0-16 8-26 18-26s18 10 18 26c-6-6-12-8-18-8s-12 2-18 8z", false), (true, "M180 102h16v24h-16z", false), (false, "M183 105h10v18h-10z", false), (false, "M150 116l8 10 8-10z", false), (true, "M56 150c0-30 18-44 44-44s44 14 44 44z", false), (true, "M92 92h16v18H92z", false), (true, "M78 76a22 24 0 1 0 44 0a22 24 0 1 0-44 0z", false), (true, "M74 80c-2-24 10-38 26-38s28 14 26 38l-4-8-2 10-6-12-4 10-6-12-4 10-6-12-4 10-6-10-2 10z", false), (false, "M91 100h18v3H91z", false), (true, "M118 92l22-4 1 3-22 4z", false), (true, "M146 80a3 3 0 1 0 .1 0zM152 70a4 4 0 1 0 .1 0z", false), (false, "M80 120l20 20 20-20-3-2-17 16-17-16z", false)],
};

/// One ink symbol (viewBox 100 × 100) for every other category.
const bookSymbols = <String, List<BookPart>>{
  "forYou": [(true, "M50 16a34 34 0 1 1 0 68 34 34 0 0 1 0-68zm0 9a25 25 0 1 0 0 50 25 25 0 0 0 0-50zm0 9a16 16 0 1 1 0 32 16 16 0 0 1 0-32zm0 8a8 8 0 1 0 0 16 8 8 0 0 0 0-16z", true), (true, "M48 48 86 10l5 5-38 38z", false), (true, "M80 6h14v14l-5-5-4 4-4-4 4-4z", false)],
  "shoujo": [(true, "M50 86C20 64 8 48 8 34a21 21 0 0 1 42-7 21 21 0 0 1 42 7c0 14-12 30-42 52z", false), (true, "M84 6l3 8 8 3-8 3-3 8-3-8-8-3 8-3zM16 70l2 5 5 2-5 2-2 5-2-5-5-2 5-2z", false)],
  "action": [(true, "M26 42c0-5 4-8 8-8h6v-6c0-4 3-7 7-7s7 3 7 7v6h3v-8c0-4 3-7 7-7s7 3 7 7v8h2c5 0 9 4 9 9v26c0 16-12 28-28 28H44c-10 0-18-8-18-18z", false), (false, "M40 34h3v18h-3zM56 34h3v20h-3zM71 36h3v18h-3z", false), (false, "M26 54h32v3H26z", false), (true, "M26 57h28a7 7 0 0 1 0 14H26z", false), (true, "M6 22l12 8-2 4-12-8zM4 46h14v4H4zM8 72l12-6 2 4-12 6z", false)],
  "adventure": [(true, "M2 92l32-54 17 26 15-20 32 48z", false), (true, "M64 26h3v24h-3z", false), (true, "M67 26h20l-5 6 5 6H67z", false), (true, "M20 14a9 9 0 1 1 0 18 9 9 0 0 1 0-18z", false)],
  "fantasy": [(true, "M50 6 74 72H26z", false), (true, "M12 72h76v9H12z", false), (true, "M76 16l3 8 8 3-8 3-3 8-3-8-8-3 8-3z", false), (false, "M44 44a6 6 0 1 1 12 0 6 6 0 0 1-12 0z", false)],
  "thriller": [(true, "M14 86 68 18c4-5 12-6 16-2s3 12-2 16L22 94z", false), (false, "M24 76l6 6-2 2-6-6z", false), (true, "M12 92a6 6 0 1 1 0 .1zM24 98a4 4 0 1 1 0 .1z", false)],
  "mystery": [(true, "M42 12a28 28 0 1 1 0 56 28 28 0 0 1 0-56zm0 10a18 18 0 1 0 0 36 18 18 0 0 0 0-36z", true), (true, "M60 62l8-8 26 26-8 8z", false)],
  "psychological": [(true, "M4 50C18 28 33 20 50 20s32 8 46 30C82 72 67 80 50 80S18 72 4 50zm46-18a18 18 0 1 0 0 36 18 18 0 0 0 0-36zm0 10a8 8 0 1 1 0 16 8 8 0 0 1 0-16z", true)],
  "romance": [(true, "M36 74C16 60 6 48 6 36a16 16 0 0 1 30-6 16 16 0 0 1 30 6c0 12-10 24-30 38zM68 92C54 82 46 74 46 66a12 12 0 0 1 22-5 12 12 0 0 1 22 5c0 8-8 16-22 26z", false)],
  "comedy": [(true, "M50 8a42 42 0 1 1 0 84 42 42 0 0 1 0-84zM26 54h48c0 15-11 24-24 24S26 69 26 54zM36 30a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM64 30a7 7 0 1 0 0 14 7 7 0 0 0 0-14z", true)],
  "drama": [(true, "M50 6C38 34 22 48 22 66a28 28 0 0 0 56 0c0-18-16-32-28-60z", false), (false, "M36 62c0 8 4 14 10 16-10 2-18-6-16-16z", false)],
  "horror": [(true, "M50 8c-23 0-38 17-38 38 0 13 7 22 15 26v18h46V72c8-4 15-13 15-26 0-21-15-38-38-38zM35 38a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM65 38a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM50 58l5 10H45z", true), (false, "M40 80h4v10h-4zM56 80h4v10h-4z", false)],
  "scifi": [(true, "M50 24a26 26 0 1 1 0 52 26 26 0 0 1 0-52z", false), (true, "M2 62c10-14 84-34 94-22 4 5-6 13-22 19l-3-7c10-4 15-7 13-8-6-4-62 8-78 24z", false)],
  "sol": [(true, "M50 10c9 0 42 56 42 66 0 9-9 14-42 14S8 85 8 76c0-10 33-66 42-66z", false), (false, "M36 64h28v24H36z", false)],
  "sports": [(true, "M50 6a44 44 0 1 1 0 88 44 44 0 0 1 0-88z", false), (false, "M12 40c25 7 51 7 76 0l2 7c-27 8-53 8-80 0zM30 70c13-5 27-5 40 0l-2 6c-12-4-24-4-36 0z", false)],
  "supernatural": [(true, "M50 4c7 19 28 27 28 52a28 28 0 0 1-56 0c0-15 8-22 15-30 2 11 6 15 11 15 0-15-5-23 2-37z", false), (false, "M50 60a10 10 0 1 1 0 20 10 10 0 0 1 0-20z", false)],
};

/// Sound effect slammed on the big panel, per category.
const bookSfx = <String, String>{
  "forYou": "TADAA !",
  "shounen": "BOUM !",
  "seinen": "SHRAK !",
  "shoujo": "KYAA !",
  "josei": "SOUPIR…",
  "action": "BAM !",
  "adventure": "WOOSH !",
  "fantasy": "FWOOSH !",
  "thriller": "TIC TAC",
  "mystery": "HMM ?",
  "psychological": "BADUM",
  "romance": "BOUM BOUM",
  "comedy": "HA HA !",
  "drama": "SNIF…",
  "horror": "CRAC !",
  "scifi": "BZZT !",
  "sol": "AAAH~",
  "sports": "SHOOT !",
  "supernatural": "WOOO…",
};
