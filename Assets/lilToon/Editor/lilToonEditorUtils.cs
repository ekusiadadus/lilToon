﻿#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Rendering;
using UnityEngine;
using UnityEngine.Rendering;
using System;
using System.Collections.Generic;
using System.IO;
#if VRC_SDK_VRCSDK3
    using VRC.SDKBase.Editor.BuildPipeline;
#endif

using Object = UnityEngine.Object;

namespace lilToon
{
    public static class lilToonEditorUtils
    {
        //------------------------------------------------------------------------------------------------------------------------------
        // Constant
        private const string menuPathAssets                 = "Assets/lilToon/";
        private const string menuPathGameObject             = "GameObject/lilToon/";
        private const string menuPathRefreshShaders         = menuPathAssets + "[Shader] Refresh shaders";
        private const string menuPathRemoveUnusedProperties = menuPathAssets + "[Material] Remove unused properties";
        private const string menuPathConvertNormal          = menuPathAssets + "[Texture] Convert normal map (DirectX <-> OpenGL)";
        private const string menuPathPixelArtReduction      = menuPathAssets + "[Texture] Pixel art reduction";
        private const string menuPathConvertGifToAtlas      = menuPathAssets + "[Texture] Convert Gif to Atlas";
        private const string menuPathSetupFromFBX           = menuPathAssets + "[Model] Setup from FBX";
        private const string menuPathFixLighting            = menuPathGameObject + "[GameObject] Fix lighting";

        private const int menuPriorityAssets = 1100;
        private const int menuPriorityGameObject = 21; // This must be 21 or less
        private const int menuPriorityRefreshShaders            = menuPriorityAssets + 0;
        private const int menuPriorityRemoveUnusedProperties    = menuPriorityAssets + 20;
        private const int menuPriorityConvertNormal             = menuPriorityAssets + 21;
        private const int menuPriorityPixelArtReduction         = menuPriorityAssets + 22;
        private const int menuPriorityConvertGifToAtlas         = menuPriorityAssets + 23;
        private const int menuPrioritySetupFromFBX              = menuPriorityAssets + 24;
        private const int menuPriorityFixLighting               = menuPriorityGameObject;

        private const string anchorName = "AutoAnchorObject";

        //------------------------------------------------------------------------------------------------------------------------------
        // Assets/lilToon/Refresh shaders
        [MenuItem(menuPathRefreshShaders, false, menuPriorityRefreshShaders)]
        private static void RefreshShaders()
        {
            if(File.Exists(lilDirectoryManager.postBuildTempPath)) File.Delete(lilDirectoryManager.postBuildTempPath);
            lilToonSetting shaderSetting = null;
            lilToonSetting.InitializeShaderSetting(ref shaderSetting);
            if(shaderSetting.isDebugOptimize)
            {
                lilToonSetting.ApplyShaderSettingOptimized();
                return;
            }
            if(lilShaderAPI.IsTextureLimitedAPI())
            {
                lilToonSetting.TurnOffAllShaderSetting(ref shaderSetting);
                lilToonSetting.CheckTextures(ref shaderSetting);
            }

            lilToonSetting.TurnOnAllShaderSetting(ref shaderSetting);
            lilToonSetting.ApplyShaderSetting(shaderSetting);

            AssetDatabase.Refresh();
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Assets/lilToon/Remove unused properties
        [MenuItem(menuPathRemoveUnusedProperties, false, menuPriorityRemoveUnusedProperties)]
        private static void RemoveUnusedProperties()
        {
            if(Selection.objects.Length == 0) return;
            Undo.RecordObjects(Selection.objects, "Remove unused properties");
            for(int i = 0; i < Selection.objects.Length; i++)
            {
                if(Selection.objects[i] is Material)
                {
                    lilMaterialUtils.RemoveUnusedTexture((Material)Selection.objects[i]);
                }
            }
        }

        [MenuItem(menuPathRemoveUnusedProperties, true, menuPriorityRemoveUnusedProperties)]
        private static bool CheckRemoveUnusedProperties()
        {
            return CheckExtension(".mat");
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Assets/lilToon/Convert normal map (DirectX <-> OpenGL)
        [MenuItem(menuPathConvertNormal, false, menuPriorityConvertNormal)]
        private static void ConvertNormal()
        {
            Texture2D srcTexture = new Texture2D(2, 2, TextureFormat.ARGB32, true, true);
            Material hsvgMaterial = new Material(Shader.Find("Hidden/ltsother_baker"));
            string path = AssetDatabase.GetAssetPath(Selection.activeObject);
            lilTextureUtils.LoadTexture(ref srcTexture, path);
            hsvgMaterial.SetTexture("_MainTex", srcTexture);
            hsvgMaterial.EnableKeyword("_NORMAL_DXGL");

            Texture2D outTexture = null;
            lilToonInspector.RunBake(ref outTexture, srcTexture, hsvgMaterial);

            // Save
            lilTextureUtils.SaveTextureToPng(path, "_conv", outTexture);
            AssetDatabase.Refresh();

            Object.DestroyImmediate(hsvgMaterial);
            Object.DestroyImmediate(srcTexture);
        }

        [MenuItem(menuPathConvertNormal, true, menuPriorityConvertNormal)]
        private static bool CheckConvertNormal()
        {
            return CheckImageExtension();
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Assets/lilToon/Convert Gif to Atlas
        #if SYSTEM_DRAWING
            // Gif to Atlas
            [MenuItem(menuPathConvertGifToAtlas, false, menuPriorityConvertGifToAtlas)]
            private static void ConvertGifToAtlas()
            {
                lilTextureUtils.ConvertGifToAtlas(Selection.activeObject);
            }

            [MenuItem(menuPathConvertGifToAtlas, true, menuPriorityConvertGifToAtlas)]
            private static bool CheckConvertGifToAtlas()
            {
                return CheckExtension(".gif");
            }
        #endif

        //------------------------------------------------------------------------------------------------------------------------------
        // Assets/lilToon/Dot texture reduction
        [MenuItem(menuPathPixelArtReduction, false, menuPriorityPixelArtReduction)]
        private static void PixelArtReduction()
        {
            Texture2D srcTexture = new Texture2D(2, 2);
            string path = AssetDatabase.GetAssetPath(Selection.activeObject);
            byte[] bytes = File.ReadAllBytes(Path.GetFullPath(path));
            srcTexture.LoadImage(bytes);
            lilTextureUtils.LoadTexture(ref srcTexture, path);
            int finalWidth;
            int finalHeight;
            int scale;
            if(EditorUtility.DisplayDialog("Dot Texture reduction",GetLoc("sUtilDotTexRedRatio"),"1/2","1/4"))
            {
                finalWidth = srcTexture.width / 2;
                finalHeight = srcTexture.height / 2;
                scale = 2;
            }
            else
            {
                finalWidth = srcTexture.width / 4;
                finalHeight = srcTexture.height / 4;
                scale = 4;
            }
            Texture2D outTex = new Texture2D(finalWidth, finalHeight);
            for(int x = 0; x < finalWidth; x++)
            {
                for(int y = 0; y < finalHeight; y++)
                {
                    outTex.SetPixel(x, y, srcTexture.GetPixel(x*scale, y*scale));
                }
            }
            outTex.Apply();

            // Save
            string savePath = lilTextureUtils.SaveTextureToPng(path, "_resized", outTex);
            AssetDatabase.Refresh();
            TextureImporter textureImporter = (TextureImporter)AssetImporter.GetAtPath(savePath);
            textureImporter.filterMode = FilterMode.Point;
            AssetDatabase.ImportAsset(savePath);
        }

        [MenuItem(menuPathPixelArtReduction, true, menuPriorityPixelArtReduction)]
        private static bool CheckPixelArtReduction()
        {
            return CheckImageExtension();
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Assets/lilToon/Setup from FBX
        [MenuItem(menuPathSetupFromFBX, false, menuPrioritySetupFromFBX)]
        private static void SetupFromFBX()
        {
            if(Selection.objects.Length == 0) return;
            Shader lts = Shader.Find("lilToon");
            if(lts == null) EditorUtility.DisplayDialog("Setup From FBX",GetLoc("sUtilShaderNotFound"),GetLoc("sCancel"));
            Undo.RecordObjects(Selection.objects, "Setup From FBX");
            foreach(Object selectionObj in Selection.objects)
            {
                string path = AssetDatabase.GetAssetPath(selectionObj);
                if(!path.EndsWith(".fbx", StringComparison.OrdinalIgnoreCase)) continue;

                ModelImporter importer = (ModelImporter)AssetImporter.GetAtPath(path);
                #if UNITY_2019_3_OR_NEWER
                    importer.materialImportMode = ModelImporterMaterialImportMode.ImportStandard;
                #else
                    importer.importMaterials = true;
                #endif

                string dirPath = Path.GetDirectoryName(path);
                string materialFolder = dirPath + "/Materials";
                if(!Directory.Exists(materialFolder))
                {
                    Directory.CreateDirectory(materialFolder);
                }
                else
                {
                    if(!EditorUtility.DisplayDialog("Setup From FBX",GetLoc("sUtilMaterialAlreadyExist"),GetLoc("sYes"),GetLoc("sNo"))) return;
                }

                lilToonSetting shaderSetting = null;
                lilToonSetting.InitializeShaderSetting(ref shaderSetting);

                // Materials in SerializedObject
                SerializedObject serializedObject = new SerializedObject(importer);
                SerializedProperty serializedObjects = serializedObject.FindProperty("m_ExternalObjects");
                for(int i = 0; i < serializedObjects.arraySize; i++)
                {
                    SerializedProperty serializedMaterial = serializedObjects.GetArrayElementAtIndex(i);
                    string propType = serializedMaterial.FindPropertyRelative("first.type").stringValue;
                    if(propType != "UnityEngine:Material") continue;

                    Material material = (Material)serializedMaterial.FindPropertyRelative("second").objectReferenceValue;
                    if(material == null)
                    {
                        material = new Material(lts)
                        {
                            name = serializedMaterial.FindPropertyRelative("first.name").stringValue
                        };
                    }
                    SetUpMaterial(ref material, materialFolder, shaderSetting);
                }

                // Materials in model
                foreach(Object obj in AssetDatabase.LoadAllAssetsAtPath(path))
                {
                    if(obj == null || !(obj is Material)) continue;
                    Material material = new Material((Material)obj);
                    SetUpMaterial(ref material, materialFolder, shaderSetting);
                }

                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();

                importer.SearchAndRemapMaterials(ModelImporterMaterialName.BasedOnMaterialName, ModelImporterMaterialSearch.Local);
                AssetDatabase.ImportAsset(path);
                AssetDatabase.Refresh();
            }
        }

        [MenuItem(menuPathSetupFromFBX, true, menuPrioritySetupFromFBX)]
        private static bool CheckSetupFromFBX()
        {
            return CheckExtension(".fbx");
        }

        private static void SetUpMaterial(ref Material material, string materialFolder, lilToonSetting shaderSetting)
        {
            if(string.IsNullOrEmpty(material.name)) return;
            string materialFileName = material.name;
            string materialLowerName = material.name.ToLower();
            if(!materialFileName.EndsWith(".mat")) materialFileName += ".mat";
            string materialPath = materialFolder + "/" + materialFileName;
            if(File.Exists(materialPath))
            {
                material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            }
            else
            {
                AssetDatabase.CreateAsset(material, materialPath);
            }
            Shader lts = Shader.Find("lilToon");
            if(lts != null) material.shader = lts;

            if(material.GetTexture("_MainTex") == null)
            {
                foreach(string texGUID in AssetDatabase.FindAssets("t:texture2d"))
                {
                    Texture2D tex = AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GUIDToAssetPath(texGUID));
                    if(tex == null) continue;
                    string texNameLow = tex.name.ToLower();
                    if(!texNameLow.Contains(materialLowerName)) continue;
                    if(lilMaterialUtils.CheckMainTextureName(texNameLow))
                    {
                        material.SetTexture("_MainTex", tex);
                        break;
                    }
                }
            }

            lilToonPreset presetSkin = null;
            lilToonPreset presetFace = null;
            lilToonPreset presetHair = null;
            lilToonPreset presetCloth = null;

            if(shaderSetting != null)
            {
                presetSkin    = shaderSetting.presetSkin;
                presetFace    = shaderSetting.presetFace;
                presetHair    = shaderSetting.presetHair;
                presetCloth   = shaderSetting.presetCloth;
            }

            if(presetSkin  == null) presetSkin  = AssetDatabase.LoadAssetAtPath<lilToonPreset>(AssetDatabase.GUIDToAssetPath("44e146d270da72d4cb21a0a3b8658d1a"));
            if(presetFace  == null) presetFace  = AssetDatabase.LoadAssetAtPath<lilToonPreset>(AssetDatabase.GUIDToAssetPath("125301c732c00f84091ef099d83833b7"));
            if(presetHair  == null) presetHair  = AssetDatabase.LoadAssetAtPath<lilToonPreset>(AssetDatabase.GUIDToAssetPath("b66bf1309c6d60847ae978e0a54ac5fa"));
            if(presetCloth == null) presetCloth = AssetDatabase.LoadAssetAtPath<lilToonPreset>(AssetDatabase.GUIDToAssetPath("193de7d9d533d4841842d8c5ed740259"));
            if(materialLowerName.Contains("face"))                                              lilToonPreset.ApplyPreset(material, presetFace, false);
            else if(materialLowerName.Contains("body") || materialLowerName.Contains("skin"))   lilToonPreset.ApplyPreset(material, presetSkin, false);
            else if(materialLowerName.Contains("hair"))                                         lilToonPreset.ApplyPreset(material, presetHair, false);
            else                                                                                lilToonPreset.ApplyPreset(material, presetCloth, false);

            bool isOutl = material.shader.name.Contains("Outline");

            if(!material.HasProperty("_ShadowStrengthMask") || material.GetTexture("_ShadowStrengthMask") == null)
            {
                foreach(string texGUID in AssetDatabase.FindAssets("t:texture2d"))
                {
                    Texture2D tex = AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GUIDToAssetPath(texGUID));
                    if(tex == null) continue;
                    string texNameLow = tex.name.ToLower();
                    if(!texNameLow.Contains(materialLowerName)) continue;
                    if((texNameLow.Contains("shadow") || texNameLow.Contains("shade")) && (texNameLow.Contains("mask") || texNameLow.Contains("strength")))
                    {
                        material.SetTexture("_ShadowStrengthMask", tex);
                        break;
                    }
                }
            }

            if(isOutl && (!material.HasProperty("_OutlineWidthMask") || material.GetTexture("_OutlineWidthMask") == null))
            {
                foreach(string texGUID in AssetDatabase.FindAssets("t:texture2d"))
                {
                    Texture2D tex = AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GUIDToAssetPath(texGUID));
                    if(tex == null) continue;
                    string texNameLow = tex.name.ToLower();
                    if(texNameLow.Contains(materialLowerName) && texNameLow.Contains("outline"))
                    {
                        material.SetTexture("_OutlineWidthMask", tex);
                        break;
                    }
                }
            }

            string mainTexLowerName = "";
            if(material.GetTexture("_MainTex") != null) mainTexLowerName = material.GetTexture("_MainTex").name.ToLower();

            if(materialLowerName.Contains("cutout") || mainTexLowerName.Contains("cutout"))
            {
                lilMaterialUtils.SetupMaterialWithRenderingMode(material, RenderingMode.Cutout, TransparentMode.Normal, isOutl, false, false, false);
            }
            else if(materialLowerName.Contains("alpha") || mainTexLowerName.Contains("alpha") || materialLowerName.Contains("fade") || mainTexLowerName.Contains("fade") || materialLowerName.Contains("transparent") || mainTexLowerName.Contains("transparent"))
            {
                lilMaterialUtils.SetupMaterialWithRenderingMode(material, RenderingMode.Transparent, TransparentMode.Normal, isOutl, false, false, false);
            }

            EditorUtility.SetDirty(material);
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // GameObject/[lilToon] Fix lighting
        [MenuItem(menuPathFixLighting, false, menuPriorityFixLighting)]
        private static void FixLighting()
        {
            GameObject gameObject = Selection.activeGameObject;
            Transform anchorTransform = gameObject.transform.Find(anchorName);
            GameObject anchorObject = anchorTransform != null ? anchorTransform.gameObject : null;
            MeshRenderer[] meshRenderers = gameObject.GetComponentsInChildren<MeshRenderer>(true);
            SkinnedMeshRenderer[] skinnedMeshRenderers = gameObject.GetComponentsInChildren<SkinnedMeshRenderer>(true);

            var recordObjects = new List<Object>{gameObject};
            recordObjects.AddRange(meshRenderers);
            recordObjects.AddRange(skinnedMeshRenderers);

            // Create Anchor
            if(anchorObject == null)
            {
                anchorObject = new GameObject(anchorName);
            }
            recordObjects.Add(anchorObject);
            Undo.RecordObjects(recordObjects.ToArray(), "[lilToon] Fix lighting");

            // Calculate avatar size
            float minX =  10000.0f;
            float minY =  10000.0f;
            float minZ =  10000.0f;
            float maxX = -10000.0f;
            float maxY = -10000.0f;
            float maxZ = -10000.0f;
            foreach(Transform objTransform in gameObject.GetComponentsInChildren<Transform>(true))
            {
                minX = minX < objTransform.position.x ? minX : objTransform.position.x;
                minY = minY < objTransform.position.y ? minY : objTransform.position.y;
                minZ = minZ < objTransform.position.z ? minZ : objTransform.position.z;
                maxX = maxX > objTransform.position.x ? maxX : objTransform.position.x;
                maxY = maxY > objTransform.position.y ? maxY : objTransform.position.y;
                maxZ = maxZ > objTransform.position.z ? maxZ : objTransform.position.z;
            }

            Vector3 centerPosition = new Vector3((minX + maxX) / 2.0f, (minY + maxY) / 2.0f, (minZ + maxZ) / 2.0f);

            anchorObject.transform.position = new Vector3(gameObject.transform.position.x, centerPosition.y, gameObject.transform.position.z);
            anchorObject.transform.parent = gameObject.transform;

            minX -= anchorObject.transform.position.x;
            minY -= anchorObject.transform.position.y;
            minZ -= anchorObject.transform.position.z;
            maxX -= anchorObject.transform.position.x;
            maxY -= anchorObject.transform.position.y;
            maxZ -= anchorObject.transform.position.z;

            float avatarWidth = -minX;
            avatarWidth = -minY > avatarWidth ? -minY : avatarWidth;
            avatarWidth = -minZ > avatarWidth ? -minZ : avatarWidth;
            avatarWidth =  maxX > avatarWidth ?  maxX : avatarWidth;
            avatarWidth =  maxY > avatarWidth ?  maxY : avatarWidth;
            avatarWidth =  maxZ > avatarWidth ?  maxZ : avatarWidth;
            avatarWidth *= 2.5f;

            lilToonSetting shaderSetting = null;
            lilToonSetting.InitializeShaderSetting(ref shaderSetting);

            // MeshRenderer
            if(meshRenderers.Length != 0)
            {
                foreach(MeshRenderer meshRenderer in meshRenderers)
                {
                    // Fix vertex light
                    foreach(Material material in meshRenderer.sharedMaterials)
                    {
                        if(material != null && material.shader != null && material.shader.name.Contains("lilToon") && shaderSetting != null)
                        {
                            Undo.RecordObject(material, "[lilToon] Fix lighting");
                            material.SetFloat("_AsUnlit", shaderSetting.defaultAsUnlit);
                            material.SetFloat("_VertexLightStrength", shaderSetting.defaultVertexLightStrength);
                            material.SetFloat("_LightMinLimit", shaderSetting.defaultLightMinLimit);
                            material.SetFloat("_LightMaxLimit", shaderSetting.defaultLightMaxLimit);
                            material.SetFloat("_BeforeExposureLimit", shaderSetting.defaultBeforeExposureLimit);
                            material.SetFloat("_MonochromeLighting", shaderSetting.defaultMonochromeLighting);
                            material.SetFloat("_lilDirectionalLightStrength", shaderSetting.defaultlilDirectionalLightStrength);
                            EditorUtility.SetDirty(material);
                        }
                    }

                    // Fix renderer settings
                    meshRenderer.probeAnchor = anchorObject.transform;
                    meshRenderer.lightProbeUsage = LightProbeUsage.BlendProbes;
                    meshRenderer.reflectionProbeUsage = ReflectionProbeUsage.BlendProbes;
                    if(meshRenderer.shadowCastingMode == ShadowCastingMode.Off)
                    {
                        meshRenderer.shadowCastingMode = ShadowCastingMode.On;
                    }
                }
            }

            // SkinnedMeshRenderer
            if(skinnedMeshRenderers.Length != 0)
            {
                foreach(SkinnedMeshRenderer skinnedMeshRenderer in skinnedMeshRenderers)
                {
                    // Fix vertex light
                    foreach(Material material in skinnedMeshRenderer.sharedMaterials)
                    {
                        if(material != null && material.shader != null && material.shader.name.Contains("lilToon") && shaderSetting != null)
                        {
                            Undo.RecordObject(material, "[lilToon] Fix lighting");
                            material.SetFloat("_AsUnlit", shaderSetting.defaultAsUnlit);
                            material.SetFloat("_VertexLightStrength", shaderSetting.defaultVertexLightStrength);
                            material.SetFloat("_LightMinLimit", shaderSetting.defaultLightMinLimit);
                            material.SetFloat("_LightMaxLimit", shaderSetting.defaultLightMaxLimit);
                            material.SetFloat("_BeforeExposureLimit", shaderSetting.defaultBeforeExposureLimit);
                            material.SetFloat("_MonochromeLighting", shaderSetting.defaultMonochromeLighting);
                            material.SetFloat("_lilDirectionalLightStrength", shaderSetting.defaultlilDirectionalLightStrength);
                            EditorUtility.SetDirty(material);
                        }
                    }

                    // Fix renderer settings
                    skinnedMeshRenderer.probeAnchor = anchorObject.transform;
                    skinnedMeshRenderer.lightProbeUsage = LightProbeUsage.BlendProbes;
                    skinnedMeshRenderer.reflectionProbeUsage = ReflectionProbeUsage.BlendProbes;
                    if(skinnedMeshRenderer.shadowCastingMode == ShadowCastingMode.Off)
                    {
                        skinnedMeshRenderer.shadowCastingMode = ShadowCastingMode.On;
                    }

                    // Fix bounds
                    if(skinnedMeshRenderer.gameObject.GetComponent<Cloth>() == null && skinnedMeshRenderer.bones != null && skinnedMeshRenderer.bones.Length != 0)
                    {
                        skinnedMeshRenderer.rootBone = anchorObject.transform;
                        skinnedMeshRenderer.localBounds = new Bounds(new Vector3(0, 0, 0), new Vector3(avatarWidth, avatarWidth, avatarWidth));
                    }
                }
            }

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorUtility.DisplayDialog("[lilToon] Fix Lighting",GetLoc("sComplete"),GetLoc("sOK"));
        }

        [MenuItem(menuPathFixLighting, true, menuPriorityFixLighting)]
        private static bool CheckFixLighting()
        {
            return Selection.activeGameObject != null;
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Format checker
        private static bool CheckExtension(string extension)
        {
            if(Selection.activeObject == null) return false;
            return AssetDatabase.GetAssetPath(Selection.activeObject).EndsWith(extension, StringComparison.OrdinalIgnoreCase);
        }

        private static bool CheckImageExtension()
        {
            if(Selection.activeObject == null) return false;
            string assetPath = AssetDatabase.GetAssetPath(Selection.activeObject);
            return assetPath.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ||
                   assetPath.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase) ||
                   assetPath.EndsWith(".jpeg", StringComparison.OrdinalIgnoreCase);
        }

        public static string GetLoc(string value) { return lilLanguageManager.GetLoc(value); }
    }

#if UNITY_2019_3_OR_NEWER
    //------------------------------------------------------------------------------------------------------------------------------
    // Build size optimization
    public class lilToonPreprocessShaders : IPreprocessShaders
    {
        public int callbackOrder { get { return default(int); } }

        public void OnProcessShader(Shader shader, ShaderSnippetData snippet, IList<ShaderCompilerData> data)
        {
            if(!shader.name.Contains("lilToon") && !shader.name.Contains("ltspass")) return;

            lilRenderPipeline lilRP = lilRenderPipelineReader.GetRP();

            if(shader.name.Contains("lilToonMulti"))
            {
                string[] keywords = GatherKeywords(shader, data);
                Material[] materials = GatherMaterials(shader);

                for(int i = data.Count - 1; i >= 0; i--)
                {
                    //bool isMatch = false;
                    if(ShouldRemoveShadowsScreen(shader, data[i].shaderKeywordSet, lilRP))
                    {
                        data.RemoveAt(i);
                        continue;
                    }
                }
            }
        }

        private Material[] GatherMaterials(Shader shader)
        {
            List<Material> materialList = new List<Material>();
            foreach(string guid in AssetDatabase.FindAssets("t:material"))
            {
                Material material = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid));
                if(material.shader == shader) materialList.Add(material);
            }
            return materialList.ToArray();
        }

        private bool IsMatchKeywords(Material material, ShaderKeywordSet shaderKeywordSet, Shader shader, string[] keywords)
        {
            foreach(string keyword in keywords)
            {
                bool materialHasKeyword = System.Array.IndexOf(material.shaderKeywords, keyword) >= 0;
                ShaderKeyword keyword2 = new ShaderKeyword(shader, keyword);
                if(materialHasKeyword && shaderKeywordSet.IsEnabled(keyword2))
                {
                    continue;
                }
                if(!materialHasKeyword && !shaderKeywordSet.IsEnabled(keyword2))
                {
                    continue;
                }
                return false;
            }
            return true;
        }

        private bool ShouldRemoveShadowsScreen(Shader shader, ShaderKeywordSet shaderKeywordSet, lilRenderPipeline RP)
        {
            ShaderKeyword _REQUIRE_UV2 = new ShaderKeyword(shader, "_REQUIRE_UV2");
            ShaderKeyword ANTI_FLICKER = new ShaderKeyword(shader, "ANTI_FLICKER");
            if(shaderKeywordSet.IsEnabled(_REQUIRE_UV2) || shaderKeywordSet.IsEnabled(ANTI_FLICKER)) return false;
            if(RP == lilRenderPipeline.BRP)
            {
                ShaderKeyword SHADOWS_SCREEN                = new ShaderKeyword(shader, "SHADOWS_SCREEN");
                return shaderKeywordSet.IsEnabled(SHADOWS_SCREEN);
            }
            else if(RP == lilRenderPipeline.LWRP || RP == lilRenderPipeline.URP)
            {
                ShaderKeyword _MAIN_LIGHT_SHADOWS           = new ShaderKeyword(shader, "_MAIN_LIGHT_SHADOWS");
                ShaderKeyword _MAIN_LIGHT_SHADOWS_CASCADE   = new ShaderKeyword(shader, "_MAIN_LIGHT_SHADOWS_CASCADE");
                ShaderKeyword _MAIN_LIGHT_SHADOWS_SCREEN    = new ShaderKeyword(shader, "_MAIN_LIGHT_SHADOWS_SCREEN");
                ShaderKeyword _SHADOWS_SOFT                 = new ShaderKeyword(shader, "_SHADOWS_SOFT");
                return shaderKeywordSet.IsEnabled(_MAIN_LIGHT_SHADOWS) || shaderKeywordSet.IsEnabled(_MAIN_LIGHT_SHADOWS_CASCADE) || shaderKeywordSet.IsEnabled(_MAIN_LIGHT_SHADOWS_SCREEN) || shaderKeywordSet.IsEnabled(_SHADOWS_SOFT);
            }
            else if(RP == lilRenderPipeline.HDRP)
            {
                ShaderKeyword SCREEN_SPACE_SHADOWS_OFF      = new ShaderKeyword(shader, "SCREEN_SPACE_SHADOWS_OFF");
                ShaderKeyword SCREEN_SPACE_SHADOWS_ON       = new ShaderKeyword(shader, "SCREEN_SPACE_SHADOWS_ON");
                ShaderKeyword SHADOW_LOW                    = new ShaderKeyword(shader, "SHADOW_LOW");
                ShaderKeyword SHADOW_MEDIUM                 = new ShaderKeyword(shader, "SHADOW_MEDIUM");
                ShaderKeyword SHADOW_HIGH                   = new ShaderKeyword(shader, "SHADOW_HIGH");
                return shaderKeywordSet.IsEnabled(SCREEN_SPACE_SHADOWS_OFF) || shaderKeywordSet.IsEnabled(SCREEN_SPACE_SHADOWS_ON) || shaderKeywordSet.IsEnabled(SHADOW_LOW) || shaderKeywordSet.IsEnabled(SHADOW_MEDIUM) || shaderKeywordSet.IsEnabled(SHADOW_HIGH);
            }
            return false;
        }

        private string[] GatherKeywords(Shader shader, IList<ShaderCompilerData> data)
        {
            List<string> keywordList = new List<string>();
            foreach(ShaderCompilerData part in data)
            {
                foreach(ShaderKeyword keyword in part.shaderKeywordSet.GetShaderKeywords())
                {
                    #if UNITY_2021_2_OR_NEWER
                        if(!ShaderKeyword.IsKeywordLocal(keyword) || keywordList.Contains(keyword.name)) continue;
                        keywordList.Add(keyword.name);
                    #else
                        if(!ShaderKeyword.IsKeywordLocal(keyword) || keywordList.Contains(ShaderKeyword.GetKeywordName(shader, keyword))) continue;
                        keywordList.Add(ShaderKeyword.GetKeywordName(shader, keyword));
                    #endif
                }
            }
            return keywordList.ToArray();
        }
    }
#endif

public class lilToonBuildProcessor : IPreprocessBuildWithReport, IPostprocessBuildWithReport
{
    public int callbackOrder { get { return 100; } }

    public void OnPreprocessBuild(UnityEditor.Build.Reporting.BuildReport report)
    {
        lilToonSetting.SetShaderSettingBeforeBuild();
    }

    public void OnPostprocessBuild(UnityEditor.Build.Reporting.BuildReport report)
    {
        lilToonSetting.SetShaderSettingAfterBuild();
    }
}

#if VRC_SDK_VRCSDK3
    //------------------------------------------------------------------------------------------------------------------------------
    // VRChat
    public class lilToonVRCBuildCallback : IVRCSDKBuildRequestedCallback, IVRCSDKPreprocessAvatarCallback, IVRCSDKPostprocessAvatarCallback
    {
        public int callbackOrder { get { return 100; } }

        #if UDON
            public bool OnBuildRequested(VRCSDKRequestedBuildType requestedBuildType)
            {
                lilToonSetting.SetShaderSettingBeforeBuild();
                EditorApplication.delayCall += () =>
                {
                    lilToonSetting.SetShaderSettingAfterBuild();
                };
                return true;
            }
        #else
            public bool OnBuildRequested(VRCSDKRequestedBuildType requestedBuildType)
            {
                lilToonSetting.ForceOptimization();
                return true;
            }
        #endif

        public bool OnPreprocessAvatar(GameObject avatarGameObject)
        {
            lilToonSetting.SetShaderSettingBeforeBuild(avatarGameObject);
            return true;
        }

        public void OnPostprocessAvatar()
        {
            lilToonSetting.SetShaderSettingAfterBuild();
        }
    }
#endif
}
#endif