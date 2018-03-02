require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    ganache: {
      host: "localhost",
      port: 7545,
      network_id: "5777"
    },
    ropsten: {
      host: "localhost",
      port: 8545,
      network_id: "3",
      from: "0xd6d0C29d11fa68d9014721B2EABf1c737E4b21dE",
      gas: 4500000
    }
  }
};
