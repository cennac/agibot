import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { connectors, confidenceMeta, liveFacts, pinmuxGroups } from './data.js';
import './styles.css';

const canvas = document.querySelector('#scene');
const stage = document.querySelector('.model-stage');
const markerLayer = document.querySelector('#markers');
const listElement = document.querySelector('#connector-list');
const detailElement = document.querySelector('#connector-detail');
const searchInput = document.querySelector('#search');
const confidenceFilter = document.querySelector('#confidence-filter');
const labelToggle = document.querySelector('#toggle-labels');

const circledNumbers = ['', '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲'];
const markerNames = {
  eth: '双千兆网口', hdmi: 'HDMI 输出', 'usb-host': 'USB 3.x 主机口', '4g-typec': '4G USB-C',
  flash: '刷机 USB', 'ttl-usb': 'TTL 控制台', 'debug-headers': 'UART / SWD', j2500: '2×5 扩展',
  antennas: '无线天线', 'usb-c-bank': 'USB-C 端口组', fan: '风扇电源', power: '主电源',
  speaker: '扬声器', 'right-harness': '主线束座', j9701: '四针线束', 'aux-top': '两针辅助座',
  core: '核心板连接器', buttons: '板载按键', 'm2-slot': 'M.2 插槽',
};
let labelsVisible = labelToggle.checked;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x111416);
scene.fog = new THREE.Fog(0x111416, 22, 40);

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
const homePosition = new THREE.Vector3(0, 12.5, 14.5);
const compactHomePosition = new THREE.Vector3(0, 17.5, 20);
camera.position.copy(homePosition);

const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.dampingFactor = 0.065;
controls.minDistance = 8;
controls.maxDistance = 31;
controls.maxPolarAngle = Math.PI * 0.49;
controls.target.set(0, 0, 0);

scene.add(new THREE.HemisphereLight(0xdde8ec, 0x18201d, 2.4));
const keyLight = new THREE.DirectionalLight(0xffffff, 3.2);
keyLight.position.set(-5, 12, 8);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(2048, 2048);
scene.add(keyLight);
const rimLight = new THREE.DirectionalLight(0x62b6a7, 1.6);
rimLight.position.set(10, 5, -8);
scene.add(rimLight);

// === 材质常量 ===
const matMetal = new THREE.MeshStandardMaterial({ color: 0xc0c4c8, roughness: 0.3, metalness: 0.85 });
const matBlack = new THREE.MeshStandardMaterial({ color: 0x15171a, roughness: 0.6, metalness: 0.1 });
const matBlue = new THREE.MeshStandardMaterial({ color: 0x1e4fb0, roughness: 0.5, metalness: 0.1 });
const matGold = new THREE.MeshStandardMaterial({ color: 0xd4a017, roughness: 0.35, metalness: 0.7 });
const matAluminum = new THREE.MeshStandardMaterial({ color: 0xa8acb0, roughness: 0.35, metalness: 0.6 });
const matWhite = new THREE.MeshStandardMaterial({ color: 0xe0e0d8, roughness: 0.7, metalness: 0.05 });
const extraParts = [];

const boardGroup = new THREE.Group();
boardGroup.rotation.y = -0.02;
scene.add(boardGroup);

const texture = new THREE.TextureLoader().load('/assets/board-top.jpg');
texture.colorSpace = THREE.SRGBColorSpace;
texture.anisotropy = renderer.capabilities.getMaxAnisotropy();

const sideMat = new THREE.MeshStandardMaterial({ color: 0x164d3c, roughness: 0.72, metalness: 0.08 });
const topMat = new THREE.MeshStandardMaterial({ map: texture, roughness: 0.82, metalness: 0.03 });
const bottomMat = new THREE.MeshStandardMaterial({ color: 0x1f6950, roughness: 0.86 });
const board = new THREE.Mesh(
  new THREE.BoxGeometry(16, 0.24, 10.4),
  [sideMat, sideMat, topMat, bottomMat, sideMat, sideMat],
);
board.castShadow = true;
board.receiveShadow = true;
boardGroup.add(board);

const boardTopY = 0.12;

// === 板载元件：RK3588 核心板芯片 + 散热片 ===
const chipBase = new THREE.Mesh(new THREE.BoxGeometry(2.6, 0.16, 2.6), matMetal);
chipBase.position.set(0, boardTopY + 0.08, 2.72);
chipBase.castShadow = true;
boardGroup.add(chipBase); extraParts.push(chipBase);
const hsBase = new THREE.Mesh(new THREE.BoxGeometry(2.5, 0.08, 2.5), matAluminum);
hsBase.position.set(0, boardTopY + 0.2, 2.72);
boardGroup.add(hsBase); extraParts.push(hsBase);
for (let i = 0; i < 9; i++) {
  const fin = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.32, 2.4), matAluminum);
  fin.position.set(-0.95 + i * 0.24, boardTopY + 0.4, 2.72);
  fin.castShadow = true;
  boardGroup.add(fin); extraParts.push(fin);
}

// === 板载元件 3D 填充（电容/IC/电感/晶振，给整板 3D 质感）===
function makeCap(r, h) {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CylinderGeometry(r, r, h, 14), matAluminum);
  body.position.y = h / 2; body.castShadow = true; g.add(body);
  const top = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.82, r * 0.82, 0.015, 14), matBlack);
  top.position.y = h / 2 + 0.008; g.add(top);
  return g;
}
function makeChip(w, d, h, color) {
  const mat = new THREE.MeshStandardMaterial({ color: color || 0x141414, roughness: 0.65, metalness: 0.12 });
  const body = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  body.position.y = h / 2; body.castShadow = true;
  // IC 顶部银色
  const lid = new THREE.Mesh(new THREE.BoxGeometry(w * 0.85, 0.01, d * 0.85), matMetal);
  lid.position.y = h + 0.005; body.add(lid);
  return body;
}
function makeInductor(w, d, h) {
  const mat = new THREE.MeshStandardMaterial({ color: 0x1a1208, roughness: 0.55, metalness: 0.35 });
  const body = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  body.position.y = h / 2; body.castShadow = true; return body;
}
function makeResistor() {
  const mat = new THREE.MeshStandardMaterial({ color: 0x221814, roughness: 0.8, metalness: 0.05 });
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.04, 0.05), mat);
  body.position.y = 0.02; return body;
}

const componentGroup = new THREE.Group();
boardGroup.add(componentGroup);

// 仅放置对照照片确定的主要大元件（位置精确，不随机散布）
// 主要 IC（对照 board-top.jpg 照片位置）
const majorComponents = [
  { type: 'chip', x: -4, z: 0.5, w: 0.9, d: 0.9, h: 0.08 },     // VL805 USB3
  { type: 'chip', x: -4.5, z: -1.5, w: 0.7, d: 0.7, h: 0.07 },   // USB Hub
  { type: 'chip', x: 3.8, z: -1.5, w: 0.6, d: 0.6, h: 0.07 },    // Genesys Hub
  { type: 'chip', x: 5, z: -0.5, w: 0.55, d: 0.55, h: 0.06 },    // ACM8625P
  { type: 'chip', x: -5.5, z: 2, w: 0.5, d: 0.5, h: 0.06 },      // PMIC
  { type: 'chip', x: 0.5, z: 0, w: 0.5, d: 0.5, h: 0.06 },       // IC
  { type: 'chip', x: -2, z: 4, w: 0.7, d: 0.5, h: 0.06 },        // IC
  { type: 'chip', x: 2, z: -3, w: 0.6, d: 0.4, h: 0.06 },        // IC
  { type: 'inductor', x: 5.5, z: 3.2, s: 0.5 },                   // 电源电感
  { type: 'inductor', x: 6.3, z: 2.4, s: 0.45 },
  { type: 'inductor', x: 4.8, z: 3.8, s: 0.5 },
  { type: 'inductor', x: 6.5, z: 3.5, s: 0.4 },
  { type: 'inductor', x: 5.2, z: 1.5, s: 0.55 },
  { type: 'xtal', x: -5.5, z: -1, w: 0.32, d: 0.14 },            // 晶振
  { type: 'xtal', x: 3, z: 1.5, w: 0.32, d: 0.14 },
  { type: 'cap', x: 5.8, z: 2.8, r: 0.13, h: 0.28 },             // 大电容
  { type: 'cap', x: 6.8, z: 2.0, r: 0.13, h: 0.28 },
  { type: 'cap', x: 4.5, z: 3.2, r: 0.12, h: 0.25 },
  { type: 'cap', x: 7.0, z: 3.2, r: 0.12, h: 0.25 },
  { type: 'cap', x: 5.0, z: 2.2, r: 0.1, h: 0.22 },
];
majorComponents.forEach((c) => {
  let mesh;
  if (c.type === 'chip' || c.type === 'xtal') mesh = makeChip(c.w, c.d, c.h, c.type === 'xtal' ? 0x999999 : 0x141414);
  else if (c.type === 'inductor') mesh = makeInductor(c.s, c.s, 0.18);
  else if (c.type === 'cap') mesh = makeCap(c.r, c.h);
  if (mesh) { mesh.position.set(c.x, boardTopY, c.z); componentGroup.add(mesh); extraParts.push(mesh); }
});

const floor = new THREE.Mesh(
  new THREE.PlaneGeometry(55, 40),
  new THREE.MeshStandardMaterial({ color: 0x171b1d, roughness: 0.95, metalness: 0.03 }),
);
floor.rotation.x = -Math.PI / 2;
floor.position.y = -0.34;
floor.receiveShadow = true;
scene.add(floor);

// === 3D 建模函数 ===
function makeRJ45() {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(1.35, 0.78, 1.55), matBlack);
  body.position.y = 0.39; body.castShadow = true; g.add(body);
  const slot = new THREE.Mesh(new THREE.BoxGeometry(1.1, 0.55, 0.85), matBlack);
  slot.position.set(0, 0.55, 0.5); g.add(slot);
  const tongue = new THREE.Mesh(new THREE.BoxGeometry(0.95, 0.06, 0.65), matGold);
  tongue.position.set(0, 0.63, 0.6); g.add(tongue);
  return g;
}
function makeUSBA() {
  const g = new THREE.Group();
  const shell = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.4, 1.35), matBlue);
  shell.position.y = 0.2; shell.castShadow = true; g.add(shell);
  const tongue = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.06, 1.0), matMetal);
  tongue.position.set(0, 0.27, 0); g.add(tongue);
  return g;
}
function makeUSBC() {
  const g = new THREE.Group();
  const shell = new THREE.Mesh(new THREE.CapsuleGeometry(0.15, 0.85, 4, 12), matBlack);
  shell.rotation.x = Math.PI / 2; shell.rotation.z = Math.PI / 2;
  shell.position.y = 0.15; g.add(shell);
  const pad = new THREE.Mesh(new THREE.BoxGeometry(0.26, 0.07, 0.95), matMetal);
  pad.position.y = 0.2; g.add(pad);
  return g;
}
function makeHDMI() {
  const g = new THREE.Group();
  const s = new THREE.Shape();
  s.moveTo(-0.8, 0); s.lineTo(0.8, 0); s.lineTo(0.7, 0.55); s.lineTo(-0.7, 0.55); s.closePath();
  const geo = new THREE.ExtrudeGeometry(s, { depth: 1.2, bevelEnabled: false });
  const body = new THREE.Mesh(geo, matMetal);
  body.rotation.x = -Math.PI / 2; body.position.y = 0.5; body.castShadow = true; g.add(body);
  return g;
}
function makeMicroUSB() {
  const g = new THREE.Group();
  const s = new THREE.Shape();
  s.moveTo(-0.35, 0); s.lineTo(0.35, 0); s.lineTo(0.3, 0.22); s.lineTo(-0.3, 0.22); s.closePath();
  const geo = new THREE.ExtrudeGeometry(s, { depth: 0.65, bevelEnabled: false });
  const body = new THREE.Mesh(geo, matBlack);
  body.rotation.x = -Math.PI / 2; body.position.y = 0.15; g.add(body);
  return g;
}
function makeHeader(rows, cols) {
  const g = new THREE.Group();
  const base = new THREE.Mesh(new THREE.BoxGeometry(cols * 0.22 + 0.1, 0.1, rows * 0.22 + 0.1), matBlack);
  base.position.y = 0.05; g.add(base);
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
    const pin = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.42, 8), matGold);
    pin.position.set(c * 0.22 - (cols - 1) * 0.11, 0.27, r * 0.22 - (rows - 1) * 0.11);
    g.add(pin);
  }
  return g;
}
function makeSMA() {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 0.22, 24), matMetal);
  body.position.y = 0.11; g.add(body);
  const pin = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.16, 12), matGold);
  pin.position.y = 0.25; g.add(pin);
  return g;
}
function makeTerminal(pins) {
  const g = new THREE.Group();
  const base = new THREE.Mesh(new THREE.BoxGeometry(pins * 0.2 + 0.1, 0.18, 0.38), matWhite);
  base.position.y = 0.09; g.add(base);
  for (let i = 0; i < pins; i++) {
    const pin = new THREE.Mesh(new THREE.CylinderGeometry(0.022, 0.022, 0.28, 8), matGold);
    pin.position.set(i * 0.2 - (pins - 1) * 0.1, 0.23, 0); g.add(pin);
  }
  return g;
}
function makeBigConn() {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.45, 1.1), matBlack);
  body.position.y = 0.23; body.castShadow = true; g.add(body);
  return g;
}
function makeB2B() {
  const g = new THREE.Group();
  for (let s = 0; s < 2; s++) {
    const body = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.16, 0.4), matBlack);
    body.position.set(0, 0.18, s === 0 ? -0.4 : 0.4); g.add(body);
    for (let i = 0; i < 20; i++) {
      const pin = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.28, 6), matGold);
      pin.position.set(i * 0.08 - 0.76, 0.31, s === 0 ? -0.4 : 0.4); g.add(pin);
    }
  }
  return g;
}
function makeM2() {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.1, 2.4), matBlack);
  body.position.y = 0.05; g.add(body);
  const contacts = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.03, 0.8), matGold);
  contacts.position.set(0, 0.09, 1.1); g.add(contacts);
  return g;
}
function makeButton() {
  const g = new THREE.Group();
  const cap = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.12, 0.1, 16), matMetal);
  cap.position.y = 0.05; g.add(cap);
  return g;
}

// === 接口 3D 模型放置 ===
const connectorMeshes = [];
function makeForConnector(c) {
  const pinsFor = { power: 3, j9701: 4, fan: 2, speaker: 2, aux_top: 2 };
  switch (c.shape) {
    case 'rj45': return makeRJ45();
    case 'usbA': return makeUSBA();
    case 'usbC': return makeUSBC();
    case 'hdmi': return makeHDMI();
    case 'microUsb': return makeMicroUSB();
    case 'sma': return makeSMA();
    case 'terminal': return makeTerminal(pinsFor[c.id] || 2);
    case 'connector': return makeBigConn();
    case 'boardToBoard': return makeB2B();
    case 'm2': return makeM2();
    case 'button': return makeButton();
    case 'header': return c.id === 'debug-headers' ? makeHeader(1, 3) : makeHeader(5, 2);
    default: return makeTerminal(2);
  }
}
connectors.forEach((c) => {
  const count = c.count || 1;
  for (let i = 0; i < count; i++) {
    const m = makeForConnector(c);
    let ox = 0, oz = 0;
    if (count > 1) {
      if (c.rot === 0 || c.rot === Math.PI) { ox = (i - (count - 1) / 2) * 0.95; }
      else { oz = (i - (count - 1) / 2) * 0.7; }
    }
    m.position.set(c.position[0] + ox, boardTopY, c.position[1] + oz);
    m.rotation.y = c.rot;
    m.userData = { id: c.id };
    m.traverse((child) => { if (child.isMesh) child.userData.id = c.id; });
    boardGroup.add(m);
    connectorMeshes.push(m);
  }
});

// === 热点环 + HTML marker（保留）===
const hotspotGroup = new THREE.Group();
boardGroup.add(hotspotGroup);
const markerEntries = [];

connectors.forEach((connector) => {
  const color = new THREE.Color(confidenceMeta[connector.confidence].color);
  const ring = new THREE.Mesh(
    new THREE.RingGeometry(0.22, 0.32, 36),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.5, side: THREE.DoubleSide }),
  );
  ring.rotation.x = -Math.PI / 2;
  ring.position.set(connector.position[0], 0.125, connector.position[1]);
  hotspotGroup.add(ring);

  const point = new THREE.Object3D();
  point.position.set(connector.position[0], 0.8, connector.position[1]);
  hotspotGroup.add(point);

  const marker = document.createElement('button');
  marker.type = 'button';
  marker.className = `marker marker-${connector.confidence}`;
  marker.classList.toggle('show-name', labelsVisible);
  marker.textContent = labelsVisible
    ? `${circledNumbers[connector.index] || connector.index} ${markerNames[connector.id] || connector.name}`
    : connector.index;
  marker.title = `${connector.name} · ${connector.designator}`;
  marker.setAttribute('aria-label', marker.title);
  marker.addEventListener('click', () => selectConnector(connector.id, true));
  markerLayer.appendChild(marker);
  markerEntries.push({ connector, marker, point, ring });
});

let selectedId = 'power';
let autoSpin = false;
let filteredIds = new Set(connectors.map((item) => item.id));

// === 高亮 3D 模型 ===
function highlightMeshes(id) {
  connectorMeshes.forEach((m) => {
    const sel = m.userData.id === id;
    m.scale.setScalar(sel ? 1.12 : 1.0);
    m.traverse((child) => {
      if (child.isMesh && child.material.emissive) {
        child.material.emissive.setHex(sel ? 0x335577 : 0x000000);
      }
    });
  });
}

function pinoutTable(rows) {
  if (!rows?.length) return '';
  return `<div class="pin-table" role="table">
    <div class="pin-row pin-head" role="row"><span>针脚</span><span>信号</span><span>说明</span></div>
    ${rows.map((row) => `<div class="pin-row" role="row"><span>${row[0]}</span><strong>${row[1]}</strong><span>${row[2] || ''}</span></div>`).join('')}
  </div>`;
}

function renderDetail(connector) {
  const meta = confidenceMeta[connector.confidence];
  detailElement.innerHTML = `
    <div class="detail-heading">
      <div><span class="category">${connector.category}</span><h2>${connector.name}</h2><p>${connector.designator}</p></div>
      <span class="confidence confidence-${connector.confidence}">${meta.label}</span>
    </div>
    <p class="summary">${connector.summary}</p>
    <div class="evidence"><span>证据</span>${connector.evidence.map((item) => `<b>${item}</b>`).join('')}</div>
    ${pinoutTable(connector.pinout)}
    ${connector.note ? `<p class="note">${connector.note}</p>` : ''}
  `;
}

function renderList() {
  const query = searchInput.value.trim().toLowerCase();
  const level = confidenceFilter.value;
  const shown = connectors.filter((connector) => {
    const matchesLevel = level === 'all' || connector.confidence === level;
    const haystack = `${connector.name} ${connector.designator} ${connector.category} ${connector.summary}`.toLowerCase();
    return matchesLevel && (!query || haystack.includes(query));
  });
  filteredIds = new Set(shown.map((item) => item.id));
  listElement.innerHTML = shown.map((connector) => `
    <button type="button" class="connector-item ${connector.id === selectedId ? 'selected' : ''}" data-id="${connector.id}">
      <span class="item-index item-${connector.confidence}">${connector.index}</span>
      <span><strong>${connector.name}</strong><small>${connector.designator}</small></span>
      <i>${confidenceMeta[connector.confidence].short}</i>
    </button>
  `).join('') || '<p class="empty-state">无匹配接口</p>';
  listElement.querySelectorAll('[data-id]').forEach((button) => {
    button.addEventListener('click', () => selectConnector(button.dataset.id, true));
  });
  markerEntries.forEach(({ connector, marker }) => marker.classList.toggle('filtered-out', !filteredIds.has(connector.id)));
}

function selectConnector(id, focus = false) {
  const connector = connectors.find((item) => item.id === id);
  if (!connector) return;
  selectedId = id;
  renderDetail(connector);
  renderList();
  highlightMeshes(id);
  markerEntries.forEach(({ connector: item, marker }) => marker.classList.toggle('selected', item.id === id));
  if (focus) {
    controls.target.set(connector.position[0] * 0.35, 0.5, connector.position[1] * 0.35);
  }
}

// === Raycaster 点击 3D 模型 ===
const raycaster = new THREE.Raycaster();
const ndc = new THREE.Vector2();
let dragMoved = false;
canvas.addEventListener('pointerdown', () => { dragMoved = false; });
canvas.addEventListener('pointermove', () => { dragMoved = true; });
canvas.addEventListener('pointerup', (e) => {
  if (dragMoved) return;
  const rect = canvas.getBoundingClientRect();
  ndc.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
  ndc.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(ndc, camera);
  const hits = raycaster.intersectObjects(connectorMeshes, true);
  if (hits.length > 0 && hits[0].object.userData.id) {
    selectConnector(hits[0].object.userData.id, true);
  }
});

searchInput.addEventListener('input', renderList);
confidenceFilter.addEventListener('change', renderList);
labelToggle.addEventListener('change', () => {
  labelsVisible = labelToggle.checked;
  markerEntries.forEach(({ connector, marker }) => {
    marker.classList.toggle('show-name', labelsVisible);
    marker.textContent = labelsVisible
      ? `${circledNumbers[connector.index] || connector.index} ${markerNames[connector.id] || connector.name}`
      : connector.index;
  });
});

document.querySelectorAll('.tab').forEach((tab) => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach((item) => item.classList.toggle('active', item === tab));
    document.querySelectorAll('.tab-panel').forEach((panel) => panel.classList.remove('active'));
    document.querySelector(`#${tab.dataset.tab}-tab`).classList.add('active');
  });
});

document.querySelector('#system-content').innerHTML = `
  <div class="section-title"><span class="online-dot"></span><div><h2>实机状态</h2><p>SSH 只读核对 · 2026-08-11</p></div></div>
  <div class="fact-grid">${liveFacts.map(([label, value]) => `<div><span>${label}</span><strong>${value}</strong></div>`).join('')}</div>
  <p class="source-note">来源：在线板 sysfs、ip、lsusb、lspci、ALSA 与本地 fdt.dtb。物理端口映射仍以逐口插拔或原理图为最终依据。</p>
`;
document.querySelector('#pinmux-content').innerHTML = pinmuxGroups.map((group) => `
  <section class="pinmux-section"><h2>${group.title}</h2>${pinoutTable(group.rows)}</section>
`).join('') + '<p class="source-note">GPIO 名称来自 fdt.dtb 的 rockchip,pins。除 UART2 调试口外，不代表已经定位到某个白色线束座。</p>';

document.querySelector('#view-home').addEventListener('click', () => {
  camera.position.copy(stage.clientWidth < 700 ? compactHomePosition : homePosition);
  controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#view-top').addEventListener('click', () => {
  camera.position.set(0, 20, 0.01); controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#view-side').addEventListener('click', () => {
  camera.position.set(18, 5.8, 0); controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#view-front').addEventListener('click', () => {
  camera.position.set(0, 6, 18); controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#view-back').addEventListener('click', () => {
  camera.position.set(0, 6, -18); controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#view-left').addEventListener('click', () => {
  camera.position.set(-18, 5.8, 0); controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#toggle-spin').addEventListener('click', (event) => {
  autoSpin = !autoSpin;
  event.currentTarget.classList.toggle('active', autoSpin);
});

const toggle3d = document.querySelector('#toggle-3d');
if (toggle3d) {
  toggle3d.addEventListener('change', () => {
    const show = toggle3d.checked;
    connectorMeshes.forEach((m) => (m.visible = show));
    extraParts.forEach((m) => (m.visible = show));
  });
}

let compactLayout = null;
function resize() {
  const width = stage.clientWidth;
  const height = stage.clientHeight;
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  const nextCompactLayout = width < 700;
  if (nextCompactLayout !== compactLayout) {
    compactLayout = nextCompactLayout;
    camera.position.copy(compactLayout ? compactHomePosition : homePosition);
    controls.target.set(0, 0, 0);
    controls.update();
  }
}

const projected = new THREE.Vector3();
function updateMarkers(time) {
  const layout = markerEntries.map((entry, index) => {
    const { connector, marker, point } = entry;
    point.getWorldPosition(projected);
    projected.project(camera);
    const rawX = (projected.x * 0.5 + 0.5) * stage.clientWidth;
    const rawY = (-projected.y * 0.5 + 0.5) * stage.clientHeight;
    const halfWidth = Math.max(marker.offsetWidth, 20) / 2;
    const halfHeight = Math.max(marker.offsetHeight, 20) / 2;
    const x = Math.min(stage.clientWidth - halfWidth - 8, Math.max(halfWidth + 8, rawX));
    const y = Math.min(stage.clientHeight - halfHeight - 8, Math.max(76, rawY));
    const visible = projected.z < 1 && filteredIds.has(connector.id);
    return { entry, index, x, y, halfWidth, halfHeight, visible };
  });
  const gap = labelsVisible ? 6 : 8;
  for (let pass = 0; pass < 12; pass += 1) {
    for (let i = 0; i < layout.length; i += 1) {
      for (let j = i + 1; j < layout.length; j += 1) {
        if (!layout[i].visible || !layout[j].visible) continue;
        const dx = layout[j].x - layout[i].x;
        const dy = layout[j].y - layout[i].y;
        const overlapX = layout[i].halfWidth + layout[j].halfWidth + gap - Math.abs(dx);
        const overlapY = layout[i].halfHeight + layout[j].halfHeight + gap - Math.abs(dy);
        if (overlapX <= 0 || overlapY <= 0) continue;
        if (overlapX < overlapY) {
          const d = dx === 0 ? (j % 2 ? 1 : -1) : Math.sign(dx);
          layout[i].x -= d * overlapX / 2; layout[j].x += d * overlapX / 2;
        } else {
          const d = dy === 0 ? (j % 2 ? 1 : -1) : Math.sign(dy);
          layout[i].y -= d * overlapY / 2; layout[j].y += d * overlapY / 2;
        }
      }
    }
    layout.forEach((item) => {
      item.x = Math.min(stage.clientWidth - item.halfWidth - 8, Math.max(item.halfWidth + 8, item.x));
      item.y = Math.min(stage.clientHeight - item.halfHeight - 8, Math.max(76, item.y));
    });
  }
  layout.forEach(({ entry, index, x, y, visible }) => {
    const { connector, marker, ring } = entry;
    marker.style.transform = `translate3d(${x}px, ${y}px, 0) translate(-50%, -50%)`;
    marker.style.visibility = visible ? 'visible' : 'hidden';
    const pulse = 1 + Math.sin(time * 0.0025 + index * 0.61) * 0.12;
    ring.scale.setScalar(connector.id === selectedId ? 1.32 : pulse);
    ring.material.opacity = connector.id === selectedId ? 0.9 : 0.5;
  });
}

function animate(time) {
  requestAnimationFrame(animate);
  if (autoSpin) boardGroup.rotation.y += 0.0016;
  controls.update();
  updateMarkers(time);
  renderer.render(scene, camera);
}

window.addEventListener('resize', resize);
resize();
renderList();
selectConnector(selectedId);
animate(0);
