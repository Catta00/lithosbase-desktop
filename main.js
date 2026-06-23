// Lithosbase desktop — sottile contenitore che apre la web app live (lithosbase.app).
// È uno "specchio" della web app: l'accesso e tutte le funzioni sono quelli del sito,
// quindi il desktop resta sempre allineato senza ricompilare nulla.
const { app, BrowserWindow, shell, Menu } = require('electron');

const APP_URL = process.env.LITHOSBASE_URL || 'https://lithosbase.app';
const APP_ORIGIN = new URL(APP_URL).origin;

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 832,
    minWidth: 960,
    minHeight: 640,
    backgroundColor: '#0d0b09',
    title: 'Lithosbase',
    autoHideMenuBar: true,
    webPreferences: {
      // sicurezza: nessun accesso a Node dalla pagina remota
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.loadURL(APP_URL);

  // I link esterni (es. PDF, social, mailto) si aprono nel browser di sistema,
  // non in una finestra Electron senza barra.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (new URL(url).origin !== APP_ORIGIN) {
      shell.openExternal(url);
      return { action: 'deny' };
    }
    return { action: 'allow' };
  });

  // Naviga internamente solo sul dominio dell'app; il resto va nel browser.
  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (new URL(url).origin !== APP_ORIGIN) {
      event.preventDefault();
      shell.openExternal(url);
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// Menu minimale: ricarica, indietro/avanti, zoom, esci (scorciatoie standard).
function buildMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac ? [{ role: 'appMenu' }] : []),
    {
      label: 'File',
      submenu: [isMac ? { role: 'close' } : { role: 'quit' }],
    },
    {
      label: 'Visualizza',
      submenu: [
        { role: 'reload' },
        { role: 'forceReload' },
        { type: 'separator' },
        { role: 'resetZoom' },
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

app.whenReady().then(() => {
  buildMenu();
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
