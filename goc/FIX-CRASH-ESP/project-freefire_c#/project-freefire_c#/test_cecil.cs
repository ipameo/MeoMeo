using System;
using System.Linq;
using Mono.Cecil;
public class P {
    public static void Main() {
        var asm = AssemblyDefinition.ReadAssembly(@"baseline\DummyDll\Assembly-CSharp.dll");
        var type = asm.MainModule.GetType("COW.GamePlay.Player");
        foreach(var f in type.Fields) {
            Console.WriteLine(f.Name + " : " + f.FieldType.FullName);
        }
    }
}
