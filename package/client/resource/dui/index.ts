import { cache } from '../cache';

const duis: Record<string, Dui> = {};
let currentId = 0;

// Pool configuration
const POOL_SIZE = 50;
const POOL_TXD_NAME = 'ox_lib_dui_pool';
let poolTxd: number | null = null;

interface TextureSlot {
  used: boolean;
  txdObject: number | null;
  version: number;
}

const textureSlots: TextureSlot[] = [];

function initPool(): void {
  if (poolTxd !== null) return;
  poolTxd = CreateRuntimeTxd(POOL_TXD_NAME);
  for (let i = 0; i < POOL_SIZE; i++) {
    textureSlots[i] = { used: false, txdObject: null, version: 0 };
  }
}

function acquireSlot(): number | null {
  initPool();
  for (let i = 0; i < POOL_SIZE; i++) {
    if (!textureSlots[i].used) {
      textureSlots[i].used = true;
      textureSlots[i].version++;
      return i;
    }
  }
  return null;
}

function releaseSlot(slotIndex: number): void {
  if (slotIndex >= 0 && textureSlots[slotIndex]) {
    textureSlots[slotIndex].used = false;
  }
}

function getSlotTextureName(slotIndex: number, version: number): string {
  return `ox_lib_dui_txt_${slotIndex}_v${version}`;
}

interface DuiProperties {
  url: string;
  width: number;
  height: number;
  debug?: boolean;
}

export class Dui {
  private id: string = '';
  private debug: boolean = false;
  private slotIndex: number = -1;
  url: string = '';
  duiObject: number = 0;
  duiHandle: string = '';
  txdObject: number = 0;
  dictName: string = '';
  txtName: string = '';

  constructor(data: DuiProperties) {
    const slotIndex = acquireSlot();
    if (slotIndex === null) {
      throw new Error(`No available texture slots in pool (max ${POOL_SIZE})`);
    }

    const time = GetGameTimer();
    const id = `${cache.resource}_${time}_${currentId}`;
    currentId++;

    const txtName = getSlotTextureName(slotIndex, textureSlots[slotIndex].version);
    const duiObject = CreateDui(data.url, data.width, data.height);
    const duiHandle = GetDuiHandle(duiObject);
    const txdObject = CreateRuntimeTextureFromDuiHandle(poolTxd!, txtName, duiHandle);

    textureSlots[slotIndex].txdObject = txdObject;

    this.id = id;
    this.debug = data.debug || false;
    this.slotIndex = slotIndex;
    this.url = data.url;
    this.duiObject = duiObject;
    this.duiHandle = duiHandle;
    this.txdObject = txdObject;
    this.dictName = POOL_TXD_NAME;
    this.txtName = txtName;
    duis[id] = this;

    if (this.debug) console.log(`Dui ${this.id} created (slot ${slotIndex})`);
  }

  remove() {
    SetDuiUrl(this.duiObject, 'about:blank');
    DestroyDui(this.duiObject);
    releaseSlot(this.slotIndex);
    delete duis[this.id];

    if (this.debug) console.log(`Dui ${this.id} removed (slot ${this.slotIndex} released)`);
  }

  setUrl(url: string) {
    this.url = url;
    SetDuiUrl(this.duiObject, url);

    if (this.debug) console.log(`Dui ${this.id} url set to ${url}`);
  }

  sendMessage(data: object) {
    SendDuiMessage(this.duiObject, JSON.stringify(data));

    if (this.debug) console.log(`Dui ${this.id} message sent with data :`, data);
  }
}

on('onResourceStop', (resourceName: string) => {
  if (cache.resource !== resourceName) return;

  for (const dui in duis) {
    duis[dui].remove();
  }
});
