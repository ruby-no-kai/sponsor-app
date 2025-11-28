[
  {
    value: 'ruby,platinum+booth,platinum',
    name: {
      ja: 'Platinum プランを希望する (ブースの有無は問わない)。不可であれば辞退する',
      en: 'Request Platinum plan (with or without booth). Withdraw if unavailable',
    },
    conditions: [
      { plans: ['Ruby'], booth_request: true },
    ],
    priority_human: ['Platinum!booth', 'Platinum!no_booth', '!withdraw'],
  },
  {
    value: 'ruby,platinum+booth',
    name: {
      ja: 'Platinum (ブースつき) を希望する。不可であれば辞退する',
      en: 'Request Platinum plan (with booth). Withdraw if unavailable',
    },
    conditions: [
      { plans: ['Ruby'], booth_request: true },
    ],
    priority_human: ['Platinum!booth', '!withdraw'],
  },
  {
    value: 'ruby,platinum+no_booth',
    name: {
      ja: 'Platinum (ブースなし) を希望する。不可であれば辞退する',
      en: 'Request Platinum plan (without booth). Withdraw if unavailable',
    },
    conditions: [
      { plans: ['Ruby'] },
    ],
    priority_human: ['Platinum!no_booth', '!withdraw'],
  },
  {
    value: 'platinum+booth,platinum,gold',
    name: {
      ja: 'ブースの有無は問わない。Platinum プランが不可であれば Gold プランに変更する',
      en: 'Accept a Platinum plan without booth. Change to Gold plan if Platinum is unavailable',
    },
    conditions: [
      { plans: ['Platinum'], booth_request: true },
    ],
    priority_human: ['{plan}!no_booth', 'Gold'],
  },
  {
    value: 'platinum+booth,platinum,silver',
    name: {
      ja: 'ブースの有無は問わない。Platinum プランが不可であれば Silver プランに変更する',
      en: 'Accept a Platinum plan without booth. Change to Silver plan if Platinum is unavailable',
    },
    conditions: [
      { plans: ['Platinum'], booth_request: true },
    ],
    priority_human: ['{plan}!no_booth', 'Silver'],
  },
  {
    value: 'platinum+booth,platinum',
    name: {
      ja: 'ブースの有無は問わない。Platinum プランに落選したら辞退する',
      en: 'Accept a Platinum plan without booth. Withdraw if Platinum is unavailable',
    },
    conditions: [
      { plans: ['Platinum'], booth_request: true },
    ],
    priority_human: ['{plan}!no_booth', '!withdraw'],
  },
  {
    value: 'gold',
    name: {
      ja: 'ブースオプションを含め希望に沿えない場合、Gold プランに変更する',
      en: 'Change to Gold plan if any of preferred option (including booth) is unavailable',
    },
    conditions: [
      { plans: ['Ruby', 'Platinum'], booth_request: true },
    ],
    priority_human: ['Gold'],
  },
  {
    value: 'silver',
    name: {
      ja: 'ブースオプションを含め希望に沿えない場合、Silver プランに変更する',
      en: 'Change to Silver plan if any of preferred option (including booth) is unavailable',
    },
    conditions: [
      { plans: ['Ruby', 'Platinum'], booth_request: true },
    ],
    priority_human: ['Silver'],
  },
  {
    value: 'gold',
    name: {
      ja: '希望に沿えない場合、Gold プランに変更する',
      en: 'Change to Gold plan if preferred option is unavailable',
    },
    conditions: [
      { plans: ['Ruby', 'Platinum'], booth_request: false },
    ],
    priority_human: ['Gold'],
  },
  {
    value: 'silver',
    name: {
      ja: '希望に沿えない場合、Silver プランに変更する',
      en: 'Change to Silver plan if preferred option is unavailable',
    },
    conditions: [
      { plans: ['Ruby', 'Platinum'], booth_request: false },
    ],
    priority_human: ['Silver'],
  },
  {
    value: 'withdraw',
    name: {
      ja: 'ブースオプションを含め希望に沿えない場合、辞退する',
      en: 'Withdraw if any of preferred option (including booth) is unavailable',
    },
    conditions: [
      { plans: ['Ruby', 'Platinum'], booth_request: true },
    ],
    priority_human: ['!withdraw'],
  },
  {
    value: 'withdraw',
    name: {
      ja: '希望に沿えない場合、辞退する',
      en: 'Withdraw if preferred option is unavailable',
    },
    conditions: [
      { plans: ['Ruby', 'Platinum'], booth_request: false },
    ],
    priority_human: ['!withdraw'],
  },
]
