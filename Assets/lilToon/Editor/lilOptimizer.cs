#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;
#if VRC_SDK_VRCSDK3 && !UDON
    using VRC.SDK3.Avatars.Components;
#endif

namespace lilToon
{
    public class lilOptimizer
    {
        private const int TYPE_OFFSET = 8;

        internal static void OptimizeInputHLSL(GameObject gameObject)
        {
            try
            {
                var dicT = new Dictionary<string, TexProp>();
                var dicD = new Dictionary<string, STProp>();
                var dicF = new Dictionary<string, FloatProp>();
                var dicC = new Dictionary<string, ColorProp>();

                // Get materials
                foreach(var renderer in gameObject.GetComponentsInChildren<Renderer>(true))
                {
                    foreach(var material in renderer.sharedMaterials)
                    {
                        CheckMaterial(material, dicT, dicD, dicF, dicC);
                    }
                }

                // Get animations
                foreach(var animator in gameObject.GetComponentsInChildren<Animator>(true))
                {
                    if(animator.runtimeAnimatorController == null) continue;
                    foreach(var clip in animator.runtimeAnimatorController.animationClips)
                    {
                        CheckAnimationClip(clip, dicT, dicD, dicF, dicC);
                    }
                }
                #if VRC_SDK_VRCSDK3 && !UDON
                    foreach(var descriptor in gameObject.GetComponentsInChildren<VRCAvatarDescriptor>(true))
                    {
                        foreach(var layer in descriptor.specialAnimationLayers)
                        {
                            if(layer.animatorController == null) continue;
                            foreach(var clip in layer.animatorController.animationClips)
                            {
                                CheckAnimationClip(clip, dicT, dicD, dicF, dicC);
                            }
                        }
                        if(descriptor.customizeAnimationLayers)
                        {
                            foreach(var layer in descriptor.baseAnimationLayers)
                            {
                                if(layer.animatorController == null) continue;
                                foreach(var clip in layer.animatorController.animationClips)
                                {
                                    CheckAnimationClip(clip, dicT, dicD, dicF, dicC);
                                }
                            }
                        }
                    }
                #endif

                // Apply
                RewriteInputHLSL(dicT, dicD, dicF, dicC);
            }
            catch(Exception e)
            {
                Debug.LogException(e);
                Debug.Log("[lilToon] OptimizeInputHLSL() failed");
            }
        }

        private static void CheckMaterial(Material material, Dictionary<string, TexProp> dicT, Dictionary<string, STProp> dicD, Dictionary<string, FloatProp> dicF, Dictionary<string, ColorProp> dicC)
        {
            if(material == null || !CheckShaderIslilToon(material.shader)) return;
            var so = new SerializedObject(material);
            var savedProps = so.FindProperty("m_SavedProperties");

            var texs = savedProps.FindPropertyRelative("m_TexEnvs");
            Check(dicT, dicD, texs, material);

            var floats = savedProps.FindPropertyRelative("m_Floats");
            Check(dicF, floats, material);

            var colors = savedProps.FindPropertyRelative("m_Colors");
            Check(dicC, colors, material);
        }

        private static void CheckAnimationClip(AnimationClip clip, Dictionary<string, TexProp> dicT, Dictionary<string, STProp> dicD, Dictionary<string, FloatProp> dicF, Dictionary<string, ColorProp> dicC)
        {
            if(clip == null) return;
            foreach(EditorCurveBinding binding in AnimationUtility.GetObjectReferenceCurveBindings(clip))
            {
                foreach(ObjectReferenceKeyframe frame in AnimationUtility.GetObjectReferenceCurve(clip, binding))
                {
                    if(frame.value is Material) CheckMaterial((Material)frame.value, dicT, dicD, dicF, dicC);
                }
            }

            foreach(EditorCurveBinding binding in AnimationUtility.GetCurveBindings(clip))
            {
                string propname = binding.propertyName;
                if(string.IsNullOrEmpty(propname) || !propname.Contains("material.")) continue;
                if(propname.Contains("_ST."))
                {
                    string name = propname.Substring(9, propname.Length - 14);
                    dicD[name] = new STProp(){isVariable = true};
                }
                else if(propname.EndsWith(".r") || propname.EndsWith(".g") || propname.EndsWith(".b") || propname.EndsWith(".a") || propname.EndsWith(".x") || propname.EndsWith(".y") || propname.EndsWith(".z") || propname.EndsWith(".w"))
                {
                    string name = propname.Substring(9, propname.Length - 11);
                    dicC[name] = new ColorProp(){isVariable = true};
                }
                else
                {
                    string name = propname.Substring(9, propname.Length - 9);
                    dicF[name] = new FloatProp(){isVariable = true};
                }
            }
        }

        private static void Check(Dictionary<string, TexProp> dic, Dictionary<string, STProp> dicD, SerializedProperty props, Material material)
        {
            for(int i = 0; i < props.arraySize; i++)
            {
                var prop = props.GetArrayElementAtIndex(i);
                string name = prop.FindPropertyRelative("first").stringValue;
                if(!material.HasProperty(name)) continue;
                var prop2 = prop.FindPropertyRelative("second");
                Object tex = prop2.FindPropertyRelative("m_Texture").objectReferenceValue;
                Vector2 scale = prop2.FindPropertyRelative("m_Scale").vector2Value;
                Vector2 offset = prop2.FindPropertyRelative("m_Offset").vector2Value;

                if(dic.ContainsKey(name))
                {
                    if(!dic[name].isVariable && dic[name].t != tex) dic[name] = new TexProp(){isVariable = true};
                }
                else
                {
                    dic[name] = new TexProp(){
                        isVariable = false,
                        t = tex
                    };
                }

                if(dicD.ContainsKey(name))
                {
                    if(!dicD[name].isVariable)
                    {
                        var v = dicD[name];
                        if(v.s != scale || v.o != offset) dicD[name] = new STProp(){isVariable = true};
                    }
                }
                else
                {
                    dicD[name] = new STProp(){
                        isVariable = false,
                        s = scale,
                        o = offset
                    };
                }
            }
        }

        private static void Check(Dictionary<string, FloatProp> dic, SerializedProperty props, Material material)
        {
            for(int i = 0; i < props.arraySize; i++)
            {
                var prop = props.GetArrayElementAtIndex(i);
                string name = prop.FindPropertyRelative("first").stringValue;
                if(!material.HasProperty(name) || dic.ContainsKey(name) && dic[name].isVariable) continue;
                float fl = prop.FindPropertyRelative("second").floatValue;
                if(dic.ContainsKey(name))
                {
                    if(dic[name].f != fl) dic[name] = new FloatProp(){isVariable = true};
                    continue;
                }
                dic[name] = new FloatProp(){
                    isVariable = false,
                    f = fl
                };
            }
        }

        private static void Check(Dictionary<string, ColorProp> dic, SerializedProperty props, Material material)
        {
            for(int i = 0; i < props.arraySize; i++)
            {
                var prop = props.GetArrayElementAtIndex(i);
                string name = prop.FindPropertyRelative("first").stringValue;
                if(!material.HasProperty(name) || dic.ContainsKey(name) && dic[name].isVariable) continue;
                Color color = prop.FindPropertyRelative("second").colorValue;
                if(dic.ContainsKey(name))
                {
                    if(dic[name].c != color) dic[name] = new ColorProp(){isVariable = true};
                    continue;
                }
                dic[name] = new ColorProp(){
                    isVariable = false,
                    c = color
                };
            }
        }

        private static void RewriteInputHLSL(Dictionary<string, TexProp> dicT, Dictionary<string, STProp> dicD, Dictionary<string, FloatProp> dicF, Dictionary<string, ColorProp> dicC)
        {
            if(dicT.Count == 0 && dicD.Count == 0 && dicF.Count == 0 && dicC.Count == 0) return;
            string pathBase = AssetDatabase.GUIDToAssetPath("8ff7f7d9c86e1154fb3aac5a8a8681bb");
            string pathOpt = AssetDatabase.GUIDToAssetPath("571051a232e4af44a98389bda858df27");
            if(string.IsNullOrEmpty(pathBase) || string.IsNullOrEmpty(pathOpt) || !File.Exists(pathBase) || !File.Exists(pathOpt)) return;
            var sb = new StringBuilder();
            var sr = new StreamReader(pathBase);
            string line;
            while((line = sr.ReadLine()) != null)
            {
                int indEND = line.IndexOf(";");
                if(indEND <= 0)
                {
                    sb.AppendLine(line);
                    continue;
                }

                int indF4 = line.IndexOf("float4  ");
                int indST = line.IndexOf("_ST;");
                int indF = line.IndexOf("float   ");
                int indI = line.IndexOf("uint    ");
                int indB = line.IndexOf("lilBool ");
                if(indF4 >= 0)
                {
                    indF4 += TYPE_OFFSET;
                    string name = line.Substring(indF4, indEND - indF4);
                    if(indST >= 0)
                    {
                        // Texture
                        string texname = name.Substring(0,name.Length - 3);
                        if(dicD.ContainsKey(texname) && !dicD[texname].isVariable)
                        {
                            var v = dicD[texname];
                            sb.AppendLine(GetIndent(indF4 - 8) + "#define " + name + " float4(" + v.s.x + "," + v.s.y + "," + v.o.x + "," + v.o.y + ")");
                            continue;
                        }
                    }
                    else
                    {
                        // Color
                        if(dicC.ContainsKey(name) && !dicC[name].isVariable)
                        {
                            var v = dicC[name];
                            sb.AppendLine(GetIndent(indF4 - 8) + "#define " + name + " float4(" + v.c.r + "," + v.c.g + "," + v.c.b + "," + v.c.a + ")");
                            continue;
                        }
                    }
                }
                else if(indF >= 0)
                {
                    // Float
                    indF += TYPE_OFFSET;
                    string name = line.Substring(indF, indEND - indF);
                    if(dicF.ContainsKey(name) && !dicF[name].isVariable)
                    {
                        sb.AppendLine(GetIndent(indF - 8) + "#define " + name + " (" + dicF[name].f + ")");
                        continue;
                    }
                }
                else if(indI >= 0)
                {
                    // Int
                    indI += TYPE_OFFSET;
                    string name = line.Substring(indI, indEND - indI);
                    if(dicF.ContainsKey(name) && !dicF[name].isVariable)
                    {
                        sb.AppendLine(GetIndent(indI - 8) + "#define " + name + " (" + (uint)dicF[name].f + ")");
                        continue;
                    }
                }
                else if(indB >= 0)
                {
                    // Bool
                    indB += TYPE_OFFSET;
                    string name = line.Substring(indB, indEND - indB);
                    if(dicF.ContainsKey(name) && !dicF[name].isVariable)
                    {
                        sb.AppendLine(GetIndent(indB - 8) + "#define " + name + " (" + (uint)dicF[name].f + ")");
                        continue;
                    }
                }
                sb.AppendLine(line);
            }
            string optHLSL = sb.ToString();
            Debug.Log(optHLSL);
            var sw = new StreamWriter(pathOpt, false);
            sw.Write(optHLSL);
            sw.Close();
            sr.Close();
        }

        internal static void ResetInputHLSL()
        {
            string pathBase = AssetDatabase.GUIDToAssetPath("8ff7f7d9c86e1154fb3aac5a8a8681bb");
            string pathOpt = AssetDatabase.GUIDToAssetPath("571051a232e4af44a98389bda858df27");
            if(string.IsNullOrEmpty(pathBase) || string.IsNullOrEmpty(pathOpt) || !File.Exists(pathBase) || !File.Exists(pathOpt)) return;
            var sw = new StreamWriter(pathOpt, false);
            var sr = new StreamReader(pathBase);
            sw.Write(sr.ReadToEnd());
            sw.Close();
            sr.Close();
        }

        private static string GetIndent(int indent)
        {
            return new string(' ', indent);
        }

        private static bool CheckShaderIslilToon(Shader shader)
        {
            if(shader == null) return false;
            if(shader.name.Contains("lilToon")) return true;
            string shaderPath = AssetDatabase.GetAssetPath(shader);
            return !string.IsNullOrEmpty(shaderPath) && shaderPath.Contains(".lilcontainer");
        }

        private struct TexProp
        {
            public bool isVariable;
            public Object t;
        }

        private struct STProp
        {
            public bool isVariable;
            public Vector2 s;
            public Vector2 o;
        }

        private struct FloatProp
        {
            public bool isVariable;
            public float f;
        }

        private struct ColorProp
        {
            public bool isVariable;
            public Color c;
        }
    }
}
#endif