// Mock CCTV Data - Kabupaten Konawe
const categories = [
  {
    id: 'PANTAU_LALIN',
    name: 'Pantau Lalin',
    icon: '🚗',
    color: '#E53935'
  },
  {
    id: 'RT_RW',
    name: 'RT RW',
    icon: '🏠',
    color: '#43A047'
  },
  {
    id: 'SUNGAI',
    name: 'Sungai',
    icon: '🌊',
    color: '#1E88E5'
  },
  {
    id: 'POMPA_AIR',
    name: 'Pantau Pompa Air',
    icon: '💧',
    color: '#00ACC1'
  },
  {
    id: 'PEMERINTAHAN',
    name: 'Kantor Pemerintahan',
    icon: '🏛️',
    color: '#8E24AA'
  },
  {
    id: 'TOL',
    name: 'Pantau Ruas Tol',
    icon: '🛣️',
    color: '#FF6F00'
  }
];

const cctvList = [
  {
    id: 'cctv-001',
    name: 'KONAWE 01 - PEREMPATAN',
    owner: 'DISKOMINFO KONAWE',
    category: 'PANTAU_LALIN',
    location: {
      lat: -3.8513609,
      lng: 122.0338782
    },
    streams: [
      {
        quality: 'preview',
        url: 'rtsp://rtspstream:3cfa6c02316a4694ba5f4b91b0cb0b1a@zephyr.rtsp.stream/movie'
      },
      {
        quality: 'main',
        url: 'rtsp://rtspstream:3cfa6c02316a4694ba5f4b91b0cb0b1a@zephyr.rtsp.stream/movie'
      }
    ],
    status: 'online',
    thumbnail: 'https://via.placeholder.com/320x180?text=KONAWE+01'
  },
  {
    id: 'cctv-002',
    name: 'KONAWE 02 - POS POLISI',
    owner: 'DISKOMINFO KONAWE',
    category: 'PANTAU_LALIN',
    location: {
      lat: -3.8530000,
      lng: 122.0350000
    },
    streams: [
      {
        quality: 'preview',
        url: 'rtsp://rtspstream:3cfa6c02316a4694ba5f4b91b0cb0b1a@zephyr.rtsp.stream/movie'
      },
      {
        quality: 'main',
        url: 'rtsp://rtspstream:3cfa6c02316a4694ba5f4b91b0cb0b1a@zephyr.rtsp.stream/movie'
      }
    ],
    status: 'online',
    thumbnail: 'https://via.placeholder.com/320x180?text=KONAWE+02'
  }
];

module.exports = {
  categories,
  cctvList
};
