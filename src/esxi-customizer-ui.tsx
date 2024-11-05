import React, { useState } from 'react';
import { 
  Upload,
  Settings,
  Package,
  Folder,
  HardDrive,
  Download,
  AlertCircle
} from 'lucide-react';
import { 
  Alert,
  AlertDescription,
  AlertTitle 
} from '@/components/ui/alert';

const ESXiCustomizer = () => {
  const [selectedVersion, setSelectedVersion] = useState('');
  const [inputBundle, setInputBundle] = useState(null);
  const [updateMode, setUpdateMode] = useState(false);
  const [pkgDirs, setPkgDirs] = useState([]);
  const [outputDir, setOutputDir] = useState('');
  const [vftEnabled, setVftEnabled] = useState(false);
  const [additionalDepots, setAdditionalDepots] = useState([]);
  const [loadVibs, setLoadVibs] = useState([]);
  const [removeVibs, setRemoveVibs] = useState([]);
  const [outputFormat, setOutputFormat] = useState('iso');
  const [customImageName, setCustomImageName] = useState('');
  const [customVendor, setCustomVendor] = useState('');
  const [customDescription, setCustomDescription] = useState('');

  const ESXiVersions = [
    { value: 'v80', label: 'ESXi 8.0' },
    { value: 'v70', label: 'ESXi 7.0' },
    { value: 'v67', label: 'ESXi 6.7' },
    { value: 'v65', label: 'ESXi 6.5' },
    { value: 'v60', label: 'ESXi 6.0' },
    { value: 'v55', label: 'ESXi 5.5' },
    { value: 'v51', label: 'ESXi 5.1' },
    { value: 'v50', label: 'ESXi 5.0' }
  ];

  const handleSubmit = (e) => {
    e.preventDefault();
    // In a real implementation, this would trigger the PowerShell script
    console.log('Configuration submitted:', {
      version: selectedVersion,
      inputBundle,
      updateMode,
      pkgDirs,
      outputDir,
      vftEnabled,
      additionalDepots,
      loadVibs,
      removeVibs,
      outputFormat,
      customImageName,
      customVendor,
      customDescription
    });
  };

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-6">
      <div className="space-y-2">
        <h1 className="text-3xl font-bold">ESXi Customizer</h1>
        <p className="text-gray-600">Create customized ESXi installation ISOs</p>
      </div>

      <Alert>
        <AlertCircle className="h-4 w-4" />
        <AlertTitle>Important</AlertTitle>
        <AlertDescription>
          This tool requires PowerCLI to be installed on your system.
        </AlertDescription>
      </Alert>

      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
          <h2 className="text-xl font-semibold flex items-center gap-2">
            <Settings className="h-5 w-5" />
            Base Configuration
          </h2>
          
          <div className="space-y-2">
            <label className="block font-medium">ESXi Version</label>
            <select 
              value={selectedVersion}
              onChange={(e) => setSelectedVersion(e.target.value)}
              className="w-full p-2 border rounded"
            >
              <option value="">Select Version</option>
              {ESXiVersions.map(version => (
                <option key={version.value} value={version.value}>
                  {version.label}
                </option>
              ))}
            </select>
          </div>

          <div className="space-y-2">
            <label className="block font-medium">Input Bundle</label>
            <div className="flex items-center gap-2">
              <input
                type="file"
                accept=".zip"
                onChange={(e) => setInputBundle(e.target.files[0])}
                className="flex-1 p-2 border rounded"
              />
              <Upload className="h-5 w-5 text-gray-500" />
            </div>
          </div>

          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={updateMode}
              onChange={(e) => setUpdateMode(e.target.checked)}
              className="rounded"
            />
            Update Mode
          </label>
        </div>

        <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
          <h2 className="text-xl font-semibold flex items-center gap-2">
            <Package className="h-5 w-5" />
            Customization Options
          </h2>

          <div className="space-y-2">
            <label className="block font-medium">Package Directories</label>
            <div className="flex items-center gap-2">
              <input
                type="text"
                value={pkgDirs.join(',')}
                onChange={(e) => setPkgDirs(e.target.value.split(','))}
                placeholder="Enter directory paths, comma-separated"
                className="flex-1 p-2 border rounded"
              />
              <Folder className="h-5 w-5 text-gray-500" />
            </div>
          </div>

          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={vftEnabled}
              onChange={(e) => setVftEnabled(e.target.checked)}
              className="rounded"
            />
            Enable V-Front Online Depot
          </label>

          <div className="space-y-2">
            <label className="block font-medium">VIBs to Load</label>
            <input
              type="text"
              value={loadVibs.join(',')}
              onChange={(e) => setLoadVibs(e.target.value.split(','))}
              placeholder="Enter VIB names, comma-separated"
              className="w-full p-2 border rounded"
            />
          </div>

          <div className="space-y-2">
            <label className="block font-medium">VIBs to Remove</label>
            <input
              type="text"
              value={removeVibs.join(',')}
              onChange={(e) => setRemoveVibs(e.target.value.split(','))}
              placeholder="Enter VIB names, comma-separated"
              className="w-full p-2 border rounded"
            />
          </div>
        </div>

        <div className="space-y-4 p-4 bg-gray-50 rounded-lg">
          <h2 className="text-xl font-semibold flex items-center gap-2">
            <HardDrive className="h-5 w-5" />
            Output Settings
          </h2>

          <div className="space-y-2">
            <label className="block font-medium">Output Format</label>
            <select 
              value={outputFormat}
              onChange={(e) => setOutputFormat(e.target.value)}
              className="w-full p-2 border rounded"
            >
              <option value="iso">ISO Image</option>
              <option value="zip">Offline Bundle (ZIP)</option>
            </select>
          </div>

          <div className="space-y-2">
            <label className="block font-medium">Output Directory</label>
            <input
              type="text"
              value={outputDir}
              onChange={(e) => setOutputDir(e.target.value)}
              placeholder="Enter output directory path"
              className="w-full p-2 border rounded"
            />
          </div>

          <div className="space-y-2">
            <label className="block font-medium">Custom Image Name</label>
            <input
              type="text"
              value={customImageName}
              onChange={(e) => setCustomImageName(e.target.value)}
              placeholder="Enter custom image name"
              className="w-full p-2 border rounded"
            />
          </div>
        </div>

        <button
          type="submit"
          className="w-full py-2 px-4 bg-blue-600 text-white rounded hover:bg-blue-700 flex items-center justify-center gap-2"
        >
          <Download className="h-5 w-5" />
          Build ESXi Image
        </button>
      </form>
    </div>
  );
};

export default ESXiCustomizer;
