require('babel-register');
require('babel-polyfill');

module.exports = {
  networks: {
    ganache: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "5777"
    },
    ropsten: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "3",
      gas: 30e5
    },
    mainnet: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "1",
      gas: 30e5
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 500
    }
  } 
};
