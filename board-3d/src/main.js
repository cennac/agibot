import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { connectors, confidenceMeta, liveFacts, pinmuxGroups, usbPortTests } from './data.js';
import './styles.css';

const canvas = document.querySelector('#scene');
const stage = document.querySelector('.model-stage');
const markerLayer = document.querySelector('#markers');
const listElement = document.querySelector('#connector-list');
const detailElement = document.querySelector('#connector-detail');
const searchInput = document.querySelector('#search');
const confidenceFilter = document.querySelector('#confidence-filter');
const labelToggle = document.querySelector('#toggle-labels');
const modelToggle = document.querySelector('#toggle-model');
const appShell = document.querySelector('.app-shell');
const inspectorToggle = document.querySelector('#toggle-inspector');

const circledNumbers = ['', '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳', '㉑', '㉒', '㉓', '㉔', '㉕', '㉖', '㉗', '㉘', '㉙'];
const markerNames = {
  eth: '双千兆网口', hdmi: 'HDMI 输出', '4g-typec': 'J9200 USB2 · 480M',
  flash: '刷机 USB', 'ttl-usb': 'TTL 控制台', 'debug-headers': 'J8900 SWD · J8901 UART0', j9702: 'J9702 CAN-A', j9703: 'J9703 CAN-B', j2500: 'J2500 双口 USB2',
  antennas: '无线天线', 'usb-c-bank': '四口 USB3 · 5Gbps', fan: '风扇电源', power: '主电源',
  j7000: 'J7000 扬声器', j7001: 'J7001 扬声器', 'right-harness': '主线束座', j9701: 'J9701 CAN-A+12V', 'aux-top': '两针辅助座',
  core: '核心板连接器', buttons: '六按键 · SW9200 LOADER · SW9201 RESET', 'm2-slot': 'M.2 插槽', j5001: 'J5001 辅助座',
  usb3000: 'USB3000 USB3 · 5Gbps',
  'j3000-lower': 'J3000 下口 USB3 · 5Gbps',
  'j3000-upper': 'J3000 上口 USB3 · 5Gbps',
  'j2900-upper': 'J2900 上口 USB3 · 5Gbps',
  'j2900-lower': 'J2900 下口 USB3 · 5Gbps',
  'j2901-lower': 'J2901 下口 USB3 · 5Gbps',
  'j2901-upper': 'J2901 上口 USB3 · 5Gbps',
};
let labelsVisible = labelToggle.checked;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x111416);
scene.fog = new THREE.Fog(0x111416, 20, 38);

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 100);
const homePosition = new THREE.Vector3(0, 15.5, 19.5);
const compactHomePosition = new THREE.Vector3(0, 21, 25.5);
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

const boardGroup = new THREE.Group();
boardGroup.rotation.y = -0.02;
// Photo rectification plus USB-A/USB-C shell dimensions place the PCB near 190 x 110 mm.
// One model unit represents approximately 10 mm; the result remains a photo-derived estimate.
const BOARD_WIDTH = 19;
const BOARD_DEPTH = 11;
const PHOTO_LAYOUT_WIDTH = 16;
const PHOTO_LAYOUT_DEPTH = 10.4;
const layoutX = (value) => value * BOARD_WIDTH / PHOTO_LAYOUT_WIDTH;
const layoutZ = (value) => value * BOARD_DEPTH / PHOTO_LAYOUT_DEPTH;
scene.add(boardGroup);

const texture = new THREE.TextureLoader().load('./assets/board-top.jpg');
texture.colorSpace = THREE.SRGBColorSpace;
texture.anisotropy = renderer.capabilities.getMaxAnisotropy();

const sideMaterial = new THREE.MeshStandardMaterial({ color: 0x164d3c, roughness: 0.72, metalness: 0.08 });
const topMaterial = new THREE.MeshStandardMaterial({ map: texture, roughness: 0.82, metalness: 0.03 });
const bottomMaterial = new THREE.MeshStandardMaterial({ color: 0x1f6950, roughness: 0.86 });
const board = new THREE.Mesh(
  new THREE.BoxGeometry(BOARD_WIDTH, 0.14, BOARD_DEPTH),
  [sideMaterial, sideMaterial, topMaterial, bottomMaterial, sideMaterial, sideMaterial],
);
// Keep the component datum at y=0.12 while using a realistic PCB thickness ratio.
board.position.y = 0.05;
board.castShadow = true;
board.receiveShadow = true;
boardGroup.add(board);

const pureModelGroup = new THREE.Group();
pureModelGroup.visible = false;
boardGroup.add(pureModelGroup);

const coreAssemblyGroup = new THREE.Group();
// The carrier PCB sits on the main-board connector plane instead of floating above it.
coreAssemblyGroup.position.y = -0.1;
pureModelGroup.add(coreAssemblyGroup);

const pureMaterials = {
  pcb: new THREE.MeshStandardMaterial({ color: 0x0a6245, roughness: 0.76, metalness: 0.04 }),
  pcbDark: new THREE.MeshStandardMaterial({ color: 0x084a38, roughness: 0.8, metalness: 0.03 }),
  metal: new THREE.MeshStandardMaterial({ color: 0xaeb7b8, roughness: 0.28, metalness: 0.78 }),
  aluminum: new THREE.MeshStandardMaterial({ color: 0xbec3c2, roughness: 0.38, metalness: 0.72 }),
  dark: new THREE.MeshStandardMaterial({ color: 0x151a1b, roughness: 0.62, metalness: 0.12 }),
  black: new THREE.MeshStandardMaterial({ color: 0x080a0b, roughness: 0.72, metalness: 0.04 }),
  white: new THREE.MeshStandardMaterial({ color: 0xd9d6c8, roughness: 0.7, metalness: 0.02 }),
  socketInner: new THREE.MeshStandardMaterial({ color: 0xbdb9aa, roughness: 0.82, metalness: 0.02 }),
  blue: new THREE.MeshStandardMaterial({ color: 0x176aaa, roughness: 0.5, metalness: 0.08 }),
  gold: new THREE.MeshStandardMaterial({ color: 0xc8942f, roughness: 0.3, metalness: 0.74 }),
  copper: new THREE.MeshStandardMaterial({ color: 0x976b48, roughness: 0.38, metalness: 0.62 }),
};

function addBox(width, height, depth, x, y, z, material, parent = pureModelGroup) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material);
  const boardRelative = parent === pureModelGroup;
  mesh.position.set(boardRelative ? layoutX(x) : x, y, boardRelative ? layoutZ(z) : z);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function addCylinder(radius, height, x, y, z, material, segments = 28, parent = pureModelGroup) {
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, height, segments), material);
  const boardRelative = parent === pureModelGroup;
  mesh.position.set(boardRelative ? layoutX(x) : x, y, boardRelative ? layoutZ(z) : z);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function addModelLabel(text, x, y, z, { width = 0.92, color = '#e9f5f0', background = 'rgba(10,18,16,.9)', fontSize = 27, parent = pureModelGroup } = {}) {
  const labelCanvas = document.createElement('canvas');
  labelCanvas.width = 256;
  labelCanvas.height = 64;
  const context = labelCanvas.getContext('2d');
  context.fillStyle = background;
  context.fillRect(2, 6, 252, 52);
  context.strokeStyle = 'rgba(90,224,160,.95)';
  context.lineWidth = 3;
  context.strokeRect(3.5, 7.5, 249, 49);
  context.fillStyle = color;
  context.font = `700 ${fontSize}px "Microsoft YaHei UI", sans-serif`;
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.fillText(text, 128, 33);

  const labelTexture = new THREE.CanvasTexture(labelCanvas);
  labelTexture.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: labelTexture, transparent: true, depthTest: false, depthWrite: false }));
  const boardRelative = parent === pureModelGroup;
  sprite.position.set(boardRelative ? layoutX(x) : x, y, boardRelative ? layoutZ(z) : z);
  sprite.scale.set(width, width * 0.25, 1);
  sprite.renderOrder = 20;
  parent.add(sprite);
  return sprite;
}

function addTopDecal(text, x, y, z, {
  width = 0.64,
  depth = 0.2,
  color = '#f4f8f6',
  background = '#17201d',
  fontSize = 32,
} = {}) {
  const decalCanvas = document.createElement('canvas');
  decalCanvas.width = 256;
  decalCanvas.height = 80;
  const context = decalCanvas.getContext('2d');
  context.fillStyle = background;
  context.fillRect(0, 0, 256, 80);
  context.strokeStyle = color;
  context.lineWidth = 4;
  context.strokeRect(3, 3, 250, 74);
  context.fillStyle = color;
  context.font = `700 ${fontSize}px "Microsoft YaHei UI", sans-serif`;
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.fillText(text, 128, 41);

  const decalTexture = new THREE.CanvasTexture(decalCanvas);
  decalTexture.colorSpace = THREE.SRGBColorSpace;
  const decal = new THREE.Mesh(
    new THREE.PlaneGeometry(width, depth),
    new THREE.MeshBasicMaterial({ map: decalTexture, transparent: true, depthWrite: false, side: THREE.DoubleSide }),
  );
  decal.rotation.x = -Math.PI / 2;
  decal.position.set(layoutX(x), y, layoutZ(z));
  decal.renderOrder = 12;
  pureModelGroup.add(decal);
  return decal;
}

function addOpenSocket(x, z, width, height, depth, pinPositions, { parent = pureModelGroup, pinSize = 0.065 } = {}) {
  const wall = 0.085;
  const base = 0.09;
  const wallHeight = height - base;
  const wallY = 0.12 + base + wallHeight / 2;
  addBox(width, base, depth, x, 0.12 + base / 2, z, pureMaterials.white, parent);
  addBox(wall, wallHeight, depth, x - (width - wall) / 2, wallY, z, pureMaterials.white, parent);
  addBox(wall, wallHeight, depth, x + (width - wall) / 2, wallY, z, pureMaterials.white, parent);
  addBox(width - wall * 2, wallHeight, wall, x, wallY, z - (depth - wall) / 2, pureMaterials.white, parent);
  addBox(width - wall * 2, wallHeight, wall, x, wallY, z + (depth - wall) / 2, pureMaterials.white, parent);
  addBox(width - wall * 2, 0.025, depth - wall * 2, x, 0.12 + base + 0.0125, z, pureMaterials.socketInner, parent);
  pinPositions.forEach(([pinX, pinZ]) => {
    addBox(pinSize, 0.24, pinSize, pinX, 0.12 + base + 0.12, pinZ, pureMaterials.copper, parent);
  });
}

function addTopPinSocket(x, z, pinCount, { pitch = 0.18, depth = 0.48, parent = pureModelGroup } = {}) {
  const width = (pinCount - 1) * pitch + 0.36;
  const pins = Array.from({ length: pinCount }, (_, pin) => [x + (pin - (pinCount - 1) / 2) * pitch, z]);
  addOpenSocket(x, z, width, 0.48, depth, pins, { parent, pinSize: 0.06 });
}

function addEdgePinSocket(x, z, pinCount, { pitch = 0.18, depth = 0.48 } = {}) {
  const width = (pinCount - 1) * pitch + 0.36;
  const height = 0.48;
  addBox(width, height, depth, x, 0.12 + height / 2, z, pureMaterials.white);
  // J9303/J5001 face the same -Z board edge as J5000 HDMI.
  const faceZ = z - depth / 2 - 0.02;
  addBox(width - 0.14, height - 0.16, 0.035, x, 0.12 + height / 2, faceZ, pureMaterials.socketInner);
  for (let pin = 0; pin < pinCount; pin += 1) {
    const pinX = x + (pin - (pinCount - 1) / 2) * pitch;
    addBox(0.026, 0.09, 0.025, pinX, 0.12 + height / 2, faceZ - 0.025, pureMaterials.copper);
  }
}

function addRightHarnessSocket(z, columns, { rows = 1, pitch = 0.17, rowPitch = 0.15, height = 0.5 } = {}) {
  const depth = (columns - 1) * pitch + 0.34;
  const width = 0.62 + (rows - 1) * rowPitch;
  const pins = [];
  for (let row = 0; row < rows; row += 1) {
    for (let column = 0; column < columns; column += 1) {
      const pinX = 7.72 + (row - (rows - 1) / 2) * rowPitch;
      const pinZ = z + (column - (columns - 1) / 2) * pitch;
      pins.push([pinX, pinZ]);
    }
  }
  addOpenSocket(7.72, z, width, height, depth, pins, { pinSize: 0.085 });
}

function addLeftPinHeader(x, z, rows, columns, { rowPitch = 0.22, columnPitch = 0.24, skip = [] } = {}) {
  const width = (rows - 1) * rowPitch + 0.28;
  const depth = (columns - 1) * columnPitch + 0.22;
  // Keep the photographed black carrier orientation; only the metal pins stand vertically.
  addBox(width, 0.18, depth, x + (rows - 1) * rowPitch / 2, 0.3, z, pureMaterials.black);
  for (let row = 0; row < rows; row += 1) {
    for (let column = 0; column < columns; column += 1) {
      const pinX = x + row * rowPitch;
      const pinZ = z + (column - (columns - 1) / 2) * columnPitch;
      if (skip.some(([skipRow, skipColumn]) => skipRow === row && skipColumn === column)) continue;
      // The user's mechanical Z-up convention maps to Three.js +Y in this scene.
      addBox(0.035, 0.72, 0.035, pinX, 0.68, pinZ, pureMaterials.copper);
      addBox(0.17, 0.18, 0.14, pinX, 0.38, pinZ, pureMaterials.black);
    }
  }
}

function capsuleShape(width, height) {
  const radius = height / 2;
  const shape = new THREE.Shape();
  shape.moveTo(-width / 2 + radius, -height / 2);
  shape.lineTo(width / 2 - radius, -height / 2);
  shape.quadraticCurveTo(width / 2, -height / 2, width / 2, 0);
  shape.quadraticCurveTo(width / 2, height / 2, width / 2 - radius, height / 2);
  shape.lineTo(-width / 2 + radius, height / 2);
  shape.quadraticCurveTo(-width / 2, height / 2, -width / 2, 0);
  shape.quadraticCurveTo(-width / 2, -height / 2, -width / 2 + radius, -height / 2);
  return shape;
}

function trapezoidShape(width, height, lowerInset) {
  const shape = new THREE.Shape();
  shape.moveTo(-width / 2 + lowerInset, -height / 2);
  shape.lineTo(width / 2 - lowerInset, -height / 2);
  shape.lineTo(width / 2, height / 2);
  shape.lineTo(-width / 2, height / 2);
  shape.closePath();
  return shape;
}

function addShapedPort(outerShape, innerShape, depth, x, y, z, rotationY = 0) {
  const body = new THREE.Mesh(
    new THREE.ExtrudeGeometry(outerShape, { depth, bevelEnabled: true, bevelSegments: 2, bevelSize: 0.025, bevelThickness: 0.025, curveSegments: 12 }),
    pureMaterials.metal,
  );
  body.position.set(layoutX(x), y, layoutZ(z));
  body.rotation.y = rotationY;
  body.castShadow = true;
  body.receiveShadow = true;
  pureModelGroup.add(body);

  const opening = new THREE.Mesh(
    new THREE.ShapeGeometry(innerShape, 16),
    new THREE.MeshStandardMaterial({ color: 0x090c0d, roughness: 0.82, metalness: 0.02, side: THREE.DoubleSide }),
  );
  const outward = new THREE.Vector3(0, 0, -0.03).applyAxisAngle(new THREE.Vector3(0, 1, 0), rotationY);
  opening.position.set(layoutX(x + outward.x), y + outward.y, layoutZ(z + outward.z));
  opening.rotation.y = rotationY + Math.PI;
  pureModelGroup.add(opening);
}

function addPortInsert(width, height, x, y, z, rotationY, material) {
  const insert = new THREE.Mesh(new THREE.PlaneGeometry(width, height), material);
  const outward = new THREE.Vector3(0, 0, -0.045).applyAxisAngle(new THREE.Vector3(0, 1, 0), rotationY);
  insert.position.set(layoutX(x + outward.x), y, layoutZ(z + outward.z));
  insert.rotation.y = rotationY + Math.PI;
  pureModelGroup.add(insert);
}

function addTypeCPort(x, z, edge = 'top') {
  const rotationY = edge === 'bottom' ? Math.PI : edge === 'left' ? Math.PI / 2 : 0;
  const y = 0.12 + 0.3 / 2;
  addShapedPort(capsuleShape(0.78, 0.3), capsuleShape(0.56, 0.14), 0.6, x, y, z, rotationY);
  addPortInsert(0.34, 0.035, x, y, z, rotationY, pureMaterials.copper);
}

function addHdmiPort(x, z) {
  const y = 0.12 + 0.25;
  addShapedPort(trapezoidShape(1.36, 0.5, 0.11), trapezoidShape(1.04, 0.24, 0.08), 0.78, x, y, z, 0);
  addPortInsert(0.66, 0.045, x, y + 0.015, z, 0, pureMaterials.copper);
}

function addMicroUsbPort(x, z) {
  addShapedPort(trapezoidShape(0.62, 0.25, 0.08), trapezoidShape(0.43, 0.12, 0.05), 0.5, x, 0.12 + 0.125, z, Math.PI / 2);
}

function addUsbAPort(x, stacked = false) {
  const height = stacked ? 1.04 : 0.66;
  addBox(1.2, height, 0.92, x, 0.12 + height / 2, -4.92, pureMaterials.metal);
  const levels = stacked ? [0.38, 0.82] : [0.4];
  levels.forEach((y) => {
    addBox(0.86, 0.28, 0.035, x, y, -5.395, pureMaterials.dark);
    addBox(0.7, 0.08, 0.045, x, y - 0.05, -5.42, pureMaterials.blue);
  });
}

function addRj45Port(x) {
  addBox(1.34, 1.02, 1.02, x, 0.63, -4.9, pureMaterials.metal);
  addBox(1.02, 0.72, 0.035, x, 0.58, -5.43, pureMaterials.dark);
  addBox(0.68, 0.08, 0.045, x, 0.87, -5.455, pureMaterials.gold);
}

// Core board, CN9800 and M.2 are independently calibrated from the bare-board top view.
addBox(9.5, 0.16, 6.2, -0.65, 0.3, -0.05, pureMaterials.pcbDark, coreAssemblyGroup);
addBox(8.35, 0.28, 0.34, -1.1, 0.48, 2.35, pureMaterials.dark, coreAssemblyGroup);

// J8600 and its card-retention post are fixed to the main board, not the removable core assembly.
addBox(0.42, 0.34, 1.65, 2.05, 0.3, 4.0, pureMaterials.dark);
addBox(0.12, 0.12, 1.35, 1.82, 0.42, 4.0, pureMaterials.gold);
addCylinder(0.18, 0.18, -1.14, 0.21, 3.97, pureMaterials.gold);

// Raised heatsink with longitudinal fins.
[-4.7, 3.25].forEach((x) => [-2.45, 2.15].forEach((z) => addCylinder(0.14, 0.46, x, 0.52, z, pureMaterials.metal, 28, coreAssemblyGroup)));
addBox(9.8, 0.34, 6.1, -0.7, 0.78, -0.15, pureMaterials.aluminum, coreAssemblyGroup);
for (let fin = 0; fin < 17; fin += 1) {
  addBox(9.65, 0.76, 0.075, -0.7, 1.28, -3.0 + fin * 0.35, pureMaterials.aluminum, coreAssemblyGroup);
}

// Fan frame, hub and seven blades.
const fanGroup = new THREE.Group();
fanGroup.position.set(-1.7, 0, -0.85);
coreAssemblyGroup.add(fanGroup);
addBox(3.0, 0.22, 0.24, 0, 1.82, -1.38, pureMaterials.black, fanGroup);
addBox(3.0, 0.22, 0.24, 0, 1.82, 1.38, pureMaterials.black, fanGroup);
addBox(0.24, 0.22, 3.0, -1.38, 1.82, 0, pureMaterials.black, fanGroup);
addBox(0.24, 0.22, 3.0, 1.38, 1.82, 0, pureMaterials.black, fanGroup);
const fanRing = new THREE.Mesh(new THREE.TorusGeometry(1.15, 0.12, 10, 48), pureMaterials.black);
fanRing.rotation.x = Math.PI / 2;
fanRing.position.y = 1.84;
fanGroup.add(fanRing);
addCylinder(0.43, 0.28, 0, 1.9, 0, pureMaterials.black, 32, fanGroup);
for (let blade = 0; blade < 7; blade += 1) {
  const angle = blade * Math.PI * 2 / 7;
  const mesh = addBox(0.82, 0.12, 0.28, Math.cos(angle) * 0.72, 1.84, Math.sin(angle) * 0.72, pureMaterials.dark, fanGroup);
  mesh.rotation.y = -angle + 0.35;
}
[[-1.22, -1.22], [1.22, -1.22], [-1.22, 1.22], [1.22, 1.22]].forEach(([x, z]) => addCylinder(0.11, 0.18, x, 1.98, z, pureMaterials.metal, 20, fanGroup));

// Board-edge I/O is calibrated from the 4096x3072 bare-board top view.
addRj45Port(-7.55);
addRj45Port(-6.08);
addHdmiPort(-3.22, -5.4);
addUsbAPort(-1.23, false);
addModelLabel('USB3000 USB3 5G', -1.23, 0.68, -4.62, { width: 1.55, fontSize: 23 });
addTypeCPort(1.23, -5.38, 'top');
addModelLabel('J9200 USB2 480M', 1.23, 0.68, -4.62, { width: 1.55, fontSize: 24 });
[3.6, 5.52, 7.38].forEach((x) => addUsbAPort(x, true));
addModelLabel('J3000 上口 USB3 5G', 3.6, 1.24, -4.55, { width: 1.75, fontSize: 21 });
addModelLabel('J3000 下口 USB3 5G', 3.6, 0.72, -4.55, { width: 1.75, fontSize: 21 });
addModelLabel('J2900 上口 USB3 5G', 5.52, 1.24, -4.55, { width: 1.75, fontSize: 21 });
addModelLabel('J2900 下口 USB3 5G', 5.52, 0.72, -4.55, { width: 1.75, fontSize: 21 });
addModelLabel('J2901 下口 USB3 5G', 7.38, 0.72, -4.55, { width: 1.75, fontSize: 21 });
addModelLabel('J2901 上口 USB3 5G', 7.38, 1.24, -4.55, { width: 1.75, fontSize: 21 });
[
  ['J3600', -7.18], ['J3500', -5.38], ['J3400', -3.63], ['J3300', -1.78],
].forEach(([designator, x]) => {
  addTypeCPort(x, 5.38, 'bottom');
  addModelLabel(`${designator} USB3 5G`, x, 0.68, 4.62, { width: 1.35, fontSize: 23 });
});
addTypeCPort(-8.1, 2.72, 'left');
addMicroUsbPort(-8.1, 3.92);

// Harness sockets expose the photographed contact count instead of using plain white blocks.
addRightHarnessSocket(-2.55, 4);
addRightHarnessSocket(-1.2, 4, { rows: 2 });
addRightHarnessSocket(0.1, 5, { rows: 2 });
addRightHarnessSocket(1.62, 3, { pitch: 0.29, height: 0.58 });
// PCB silkscreen aligned with the three J2000 contacts: X, VIN+, VIN-.
addTopDecal('X', 6.75, 0.205, 1.33, { width: 0.72, depth: 0.22, color: '#f4f7f6', background: '#33403c', fontSize: 38 });
addTopDecal('VIN+', 6.75, 0.205, 1.62, { width: 0.88, depth: 0.22, color: '#eafff0', background: '#12673b', fontSize: 34 });
addTopDecal('VIN-', 6.75, 0.205, 1.91, { width: 0.88, depth: 0.22, color: '#ffe7e7', background: '#8b1f28', fontSize: 34 });

// In the full-board photo the speaker sockets are inboard of the capacitors and vertically staggered.
addTopPinSocket(5.38, 0.58, 2);
addTopPinSocket(5.38, -0.12, 2);
addModelLabel('J7000 SPK', 5.05, 0.72, 0.82, { width: 1.05, fontSize: 26 });
addModelLabel('J7001 SPK', 5.05, 0.72, -0.38, { width: 1.05, fontSize: 26 });
addTopPinSocket(-4.55, 3.72, 2, { depth: 0.55 });
addEdgePinSocket(-4.62, -4.72, 2);
addEdgePinSocket(0.25, -4.72, 2);

// Antenna sockets follow the left-edge order in the rotated detail photo: headers, ANT6301, ANT6300.
[0.65, 1.75].forEach((z) => {
  addCylinder(0.24, 0.24, -7.42, 0.34, z, pureMaterials.gold);
  addCylinder(0.11, 0.3, -7.42, 0.54, z, pureMaterials.gold);
});
// Two speaker filter capacitors sit between the edge harnesses and the speaker sockets.
[[6.12, 0.08], [6.12, -0.72], [6.55, 3.15]].forEach(([x, z]) => {
  addCylinder(0.25, 0.5, x, 0.46, z, pureMaterials.metal);
  addCylinder(0.2, 0.04, x, 0.73, z, pureMaterials.white);
});
[[6.75, -0.15], [6.75, 0.75]].forEach(([x, z]) => addBox(0.48, 0.34, 0.48, x, 0.4, z, pureMaterials.dark));
// The power area contains one visibly larger IC, not two separate small packages.
addBox(0.82, 0.22, 0.68, 6.72, 0.25, 2.62, pureMaterials.black);
// Photo orientation: three buttons per row. Top: SW8902/01/00; bottom: SW9202/00/01.
const buttonRows = [
  { z: -1.32, labelZ: -1.63, ids: ['SW8902', 'SW8901', 'SW8900'] },
  { z: -0.74, labelZ: -0.43, ids: ['SW9202', 'SW9200', 'SW9201'] },
];
const buttonXs = [-7.0, -6.45, -5.9];
buttonRows.forEach(({ z, labelZ, ids }) => {
  buttonXs.forEach((x, index) => {
    addBox(0.34, 0.12, 0.28, x, 0.29, z, pureMaterials.metal);
    addBox(0.2, 0.05, 0.14, x, 0.38, z, pureMaterials.white);
    addTopDecal(ids[index], x, 0.205, labelZ, {
      width: 0.5,
      depth: 0.13,
      color: ids[index] === 'SW9200' ? '#fff4bf' : ids[index] === 'SW9201' ? '#ffe7e7' : '#f4f8f6',
      background: ids[index] === 'SW9200' ? '#6b4b00' : ids[index] === 'SW9201' ? '#8b1f28' : '#24312d',
      fontSize: 28,
    });
  });
});
addTopDecal('LOADER', -6.45, 0.205, -0.24, {
  width: 0.62,
  depth: 0.14,
  color: '#fff4bf',
  background: '#6b4b00',
  fontSize: 30,
});
addTopDecal('RESET', -5.9, 0.205, -0.24, {
  width: 0.58, depth: 0.14, color: '#ffe7e7', background: '#8b1f28', fontSize: 30,
});

// J2500 follows the keyed 2x5 USB 2.0 header shape: pin 9 is physically absent.
addLeftPinHeader(-7.55, -0.25, 2, 5, { skip: [[1, 4]] });
// J8901 is the outer carrier at the board edge; J8900 is the inner carrier.
addLeftPinHeader(-7.62, -1.55, 1, 3);
addLeftPinHeader(-7.18, -1.55, 1, 3);
addModelLabel('J2500 USB2 x2 · 9pin', -7.18, 0.7, -0.25, { width: 1.36 });
addModelLabel('J8901 · UART0', -7.62, 0.7, -1.08, { width: 1.2 });
addModelLabel('J8900 · SWD', -7.18, 0.7, -2.02, { width: 1.08 });

// IMG_20260812_114650: J9703/J9702 are the upper/lower 1x3 rows directly below J7000.
// Three pins run along X in each row; together the two carriers have a 2x3 appearance.
addLeftPinHeader(5.16, 1.05, 3, 1);
addLeftPinHeader(5.16, 1.42, 3, 1);
addModelLabel('J9703 1x3', 4.75, 0.78, 1.05, { width: 1.02 });
addModelLabel('J9702 1x3', 5.95, 0.78, 1.42, { width: 1.02 });

// Five plated holes are measured from the bare-board image around J3300-J3600.
[-7.78, -6.25, -4.47, -2.65, -0.92].forEach((x) => {
  addCylinder(0.18, 0.05, x, 0.18, 5.03, pureMaterials.gold);
  addCylinder(0.08, 0.07, x, 0.2, 5.03, pureMaterials.dark);
});

function setModelMode() {
  const pure = modelToggle.checked;
  pureModelGroup.visible = pure;
  topMaterial.map = pure ? null : texture;
  topMaterial.color.setHex(pure ? 0x0c6a4c : 0xffffff);
  topMaterial.roughness = pure ? 0.68 : 0.82;
  topMaterial.needsUpdate = true;
  stage.classList.toggle('pure-model', pure);
  canvas.setAttribute('aria-label', pure ? '无贴图纯三维板卡模型' : '照片贴图三维板卡模型');
}

const floor = new THREE.Mesh(
  new THREE.PlaneGeometry(55, 40),
  new THREE.MeshStandardMaterial({ color: 0x171b1d, roughness: 0.95, metalness: 0.03 }),
);
floor.rotation.x = -Math.PI / 2;
floor.position.y = -0.34;
floor.receiveShadow = true;
scene.add(floor);

const hotspotGroup = new THREE.Group();
boardGroup.add(hotspotGroup);
const markerEntries = [];

connectors.forEach((connector) => {
  const color = new THREE.Color(confidenceMeta[connector.confidence].color);
  const ring = new THREE.Mesh(
    new THREE.RingGeometry(0.18, 0.29, 36),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.86, side: THREE.DoubleSide }),
  );
  ring.rotation.x = -Math.PI / 2;
  ring.position.set(layoutX(connector.position[0]), 0.34, layoutZ(connector.position[1]));
  hotspotGroup.add(ring);

  const point = new THREE.Object3D();
  point.position.set(layoutX(connector.position[0]), connector.markerHeight ?? 0.46, layoutZ(connector.position[1]));
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

function pinoutTable(rows) {
  if (!rows?.length) return '';
  return `<div class="pin-table" role="table">
    <div class="pin-row pin-head" role="row"><span>针脚</span><span>信号</span><span>说明</span></div>
    ${rows.map((row) => `<div class="pin-row" role="row"><span>${row[0]}</span><strong>${row[1]}</strong><span>${row[2] || ''}</span></div>`).join('')}
  </div>`;
}

function usbTestTable(rows) {
  return `<div class="usb-test-table" role="region" aria-label="USB 物理端口测试记录" tabindex="0">
    <table>
      <thead><tr><th>物理接口</th><th>日期 / 状态</th><th>总线端口路径</th><th>控制器</th><th>协商结果</th></tr></thead>
      <tbody>${rows.map((row) => `<tr><th>${row.port}</th><td>${row.date}<br><span>${row.status}</span></td><td>${row.topology}</td><td>${row.controller}</td><td>${row.result}</td></tr>`).join('')}</tbody>
    </table>
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
  markerEntries.forEach(({ connector: item, marker }) => marker.classList.toggle('selected', item.id === id));
  if (focus) {
    controls.target.set(layoutX(connector.position[0]) * 0.35, 0, layoutZ(connector.position[1]) * 0.35);
  }
}

searchInput.addEventListener('input', renderList);
confidenceFilter.addEventListener('change', renderList);
modelToggle.addEventListener('change', setModelMode);
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

function setInspectorCollapsed(collapsed) {
  appShell.classList.toggle('inspector-collapsed', collapsed);
  inspectorToggle.textContent = collapsed ? '‹' : '›';
  inspectorToggle.title = collapsed ? '展开信息面板' : '收起信息面板';
  inspectorToggle.setAttribute('aria-label', inspectorToggle.title);
  inspectorToggle.setAttribute('aria-expanded', String(!collapsed));
}

inspectorToggle.addEventListener('click', () => {
  setInspectorCollapsed(!appShell.classList.contains('inspector-collapsed'));
});

document.querySelector('#system-content').innerHTML = `
  <div class="section-title"><span class="online-dot"></span><div><h2>实机状态</h2><p>SSH 只读核对 · 更新至 2026-08-12</p></div></div>
  <div class="fact-grid">${liveFacts.map(([label, value]) => `<div><span>${label}</span><strong>${value}</strong></div>`).join('')}</div>
  <section class="usb-test-section"><h2>USB 逐口测试</h2>${usbTestTable(usbPortTests)}</section>
  <p class="source-note">表中 480/5000 Mbit/s 均为 USB 总线实际协商值，不等于文件读写速度。J3300 已出现 SuperSpeed Gen 1；J9200 当前只出现 USB 2.0 High-Speed。其他物理端口仍以逐口插拔后的 sysfs 结果为准。</p>
`;

document.querySelector('#pinmux-content').innerHTML = pinmuxGroups.map((group) => `
  <section class="pinmux-section"><h2>${group.title}</h2>${pinoutTable(group.rows)}</section>
`).join('') + '<p class="source-note">GPIO 名称来自 fdt.dtb 的 rockchip,pins。除 UART2 调试口外，不代表已经定位到某个白色线束座。</p>';

document.querySelector('#view-home').addEventListener('click', () => {
  camera.position.copy(stage.clientWidth < 700 ? compactHomePosition : homePosition);
  controls.target.set(0, 0, 0); controls.update();
});

function distanceToFitWidth(width) {
  const verticalFov = THREE.MathUtils.degToRad(camera.fov);
  return (width / 2) / (Math.tan(verticalFov / 2) * camera.aspect);
}

document.querySelector('#view-top').addEventListener('click', () => {
  const distance = Math.max(23, distanceToFitWidth(20.4));
  camera.position.set(0, distance, 0.01); controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#view-ports').addEventListener('click', () => {
  const targetZ = -2.15;
  const distance = Math.max(25, distanceToFitWidth(20.4));
  camera.position.set(0, 6.1, targetZ - distance); controls.target.set(0, 0.45, targetZ); controls.update();
});
document.querySelector('#view-side').addEventListener('click', () => {
  camera.position.set(21, 5.8, 0); controls.target.set(0, 0, 0); controls.update();
});
document.querySelector('#toggle-spin').addEventListener('click', (event) => {
  autoSpin = !autoSpin;
  event.currentTarget.classList.toggle('active', autoSpin);
});

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
          const direction = dx === 0 ? (j % 2 ? 1 : -1) : Math.sign(dx);
          layout[i].x -= direction * overlapX / 2;
          layout[j].x += direction * overlapX / 2;
        } else {
          const direction = dy === 0 ? (j % 2 ? 1 : -1) : Math.sign(dy);
          layout[i].y -= direction * overlapY / 2;
          layout[j].y += direction * overlapY / 2;
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
    ring.material.opacity = connector.id === selectedId ? 1 : 0.72;
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
new ResizeObserver(resize).observe(stage);
resize();
setModelMode();
renderList();
selectConnector(selectedId);
animate(0);
